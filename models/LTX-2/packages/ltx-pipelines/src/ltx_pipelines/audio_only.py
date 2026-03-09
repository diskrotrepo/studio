import argparse
import logging

import torch

from ltx_core.components.diffusion_steps import EulerDiffusionStep
from ltx_core.components.guiders import MultiModalGuiderParams, create_multimodal_guider_factory
from ltx_core.components.noisers import GaussianNoiser
from ltx_core.components.protocols import DiffusionStepProtocol
from ltx_core.loader import LoraPathStrengthAndSDOps
from ltx_core.model.audio_vae import decode_audio as vae_decode_audio
from ltx_core.quantization import QuantizationPolicy
from ltx_core.types import Audio, LatentState, VideoPixelShape
from ltx_pipelines.utils import euler_denoising_loop
from ltx_pipelines.utils.args import LoraAction, QuantizationAction, resolve_path
from ltx_pipelines.utils.constants import DISTILLED_SIGMA_VALUES
from ltx_pipelines.utils.helpers import (
    cleanup_memory,
    denoise_audio_only,
    encode_prompts,
    get_device,
    guided_audio_only_denoising_func,
    simple_audio_only_denoising_func,
)
from ltx_pipelines.utils.media_io import encode_audio_wav
from ltx_pipelines.utils.model_ledger import AudioOnlyModelLedger
from ltx_pipelines.utils.types import PipelineComponents

device = get_device()


class AudioOnlyPipeline:
    """
    Audio-only generation pipeline.
    Generates audio from text prompts without any video generation.
    Uses only the audio stream of the transformer, audio decoder, vocoder,
    and text encoder. No video VAE or spatial upsampler needed.
    """

    def __init__(
        self,
        checkpoint_path: str,
        gemma_root: str,
        loras: list[LoraPathStrengthAndSDOps],
        device: torch.device = device,
        quantization: QuantizationPolicy | None = None,
    ):
        self.device = device
        self.dtype = torch.bfloat16

        self.model_ledger = AudioOnlyModelLedger(
            dtype=self.dtype,
            device=device,
            checkpoint_path=checkpoint_path,
            gemma_root_path=gemma_root,
            loras=loras,
            quantization=quantization,
        )

        self.pipeline_components = PipelineComponents(
            dtype=self.dtype,
            device=device,
        )

    def __call__(
        self,
        prompt: str,
        seed: int,
        num_frames: int,
        frame_rate: float,
        enhance_prompt: bool = False,
        negative_prompt: str = "",
        audio_cfg_guidance_scale: float = 7.0,
        audio_stg_guidance_scale: float = 1.0,
        audio_rescale_scale: float = 0.7,
    ) -> Audio:
        generator = torch.Generator(device=self.device).manual_seed(seed)
        noiser = GaussianNoiser(generator=generator)
        stepper = EulerDiffusionStep()
        dtype = torch.bfloat16

        use_guidance = audio_cfg_guidance_scale != 1.0 or audio_stg_guidance_scale > 0.0

        if negative_prompt and use_guidance:
            ctx_p, ctx_n = encode_prompts(
                [prompt, negative_prompt],
                self.model_ledger,
                enhance_first_prompt=enhance_prompt,
            )
            negative_audio_context = ctx_n.audio_encoding
        else:
            (ctx_p,) = encode_prompts(
                [prompt],
                self.model_ledger,
                enhance_first_prompt=enhance_prompt,
            )
            negative_audio_context = None

        audio_context = ctx_p.audio_encoding

        transformer = self.model_ledger.transformer()
        sigmas = torch.Tensor(DISTILLED_SIGMA_VALUES).to(self.device)

        output_shape = VideoPixelShape(
            batch=1,
            frames=num_frames,
            width=64,
            height=64,
            fps=frame_rate,
        )

        if use_guidance:
            audio_guider_params = MultiModalGuiderParams(
                cfg_scale=audio_cfg_guidance_scale,
                stg_scale=audio_stg_guidance_scale,
                rescale_scale=audio_rescale_scale,
                modality_scale=1.0,
                skip_step=0,
                stg_blocks=[29],
            )
            audio_guider_factory = create_multimodal_guider_factory(
                params=audio_guider_params,
                negative_context=negative_audio_context,
            )
            denoise_fn = guided_audio_only_denoising_func(
                audio_guider_factory=audio_guider_factory,
                audio_context=audio_context,
                transformer=transformer,
            )
        else:
            denoise_fn = simple_audio_only_denoising_func(
                audio_context=audio_context,
                transformer=transformer,
            )

        def denoising_loop(
            sigmas: torch.Tensor, video_state: LatentState, audio_state: LatentState, stepper: DiffusionStepProtocol
        ) -> tuple[LatentState, LatentState]:
            return euler_denoising_loop(
                sigmas=sigmas,
                video_state=video_state,
                audio_state=audio_state,
                stepper=stepper,
                denoise_fn=denoise_fn,
            )

        audio_state = denoise_audio_only(
            output_shape=output_shape,
            noiser=noiser,
            sigmas=sigmas,
            stepper=stepper,
            denoising_loop_fn=denoising_loop,
            components=self.pipeline_components,
            dtype=dtype,
            device=self.device,
        )

        torch.cuda.synchronize()
        del transformer
        cleanup_memory()

        decoded_audio = vae_decode_audio(
            audio_state.latent, self.model_ledger.audio_decoder(), self.model_ledger.vocoder()
        )
        return decoded_audio


def audio_only_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Generate audio from a text prompt (no video).")
    parser.add_argument(
        "--checkpoint-path",
        type=resolve_path,
        required=True,
        help="Path to LTX-2 model checkpoint (.safetensors file). Can be the full AV checkpoint or an audio-only extract.",
    )
    parser.add_argument(
        "--gemma-root",
        type=resolve_path,
        required=True,
        help="Path to the root directory containing the Gemma text encoder model files.",
    )
    parser.add_argument(
        "--prompt",
        type=str,
        required=True,
        help="Text prompt describing the desired audio content.",
    )
    parser.add_argument(
        "--output-path",
        type=resolve_path,
        required=True,
        help="Path to the output WAV file.",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=171198,
        help="Random seed for reproducible generation (default: 171198).",
    )
    parser.add_argument(
        "--num-frames",
        type=int,
        default=121,
        help="Number of frames (controls audio duration via frame_rate). num_frames / frame_rate = duration in seconds. Default: 121.",
    )
    parser.add_argument(
        "--frame-rate",
        type=float,
        default=24.0,
        help="Frame rate used to compute audio duration (default: 24.0).",
    )
    parser.add_argument("--enhance-prompt", action="store_true")
    parser.add_argument(
        "--lora",
        dest="lora",
        action=LoraAction,
        nargs="+",
        metavar=("PATH", "STRENGTH"),
        default=[],
        help="LoRA model: path and optional strength. Can be specified multiple times.",
    )
    parser.add_argument(
        "--quantization",
        dest="quantization",
        action=QuantizationAction,
        nargs="+",
        default=None,
        help="Quantization policy (e.g., fp8-cast, fp8-scaled-mm).",
    )
    return parser


@torch.inference_mode()
def main() -> None:
    logging.getLogger().setLevel(logging.INFO)
    args = audio_only_arg_parser().parse_args()

    pipeline = AudioOnlyPipeline(
        checkpoint_path=args.checkpoint_path,
        gemma_root=args.gemma_root,
        loras=tuple(args.lora) if args.lora else (),
        quantization=args.quantization,
    )

    audio = pipeline(
        prompt=args.prompt,
        seed=args.seed,
        num_frames=args.num_frames,
        frame_rate=args.frame_rate,
        enhance_prompt=args.enhance_prompt,
    )

    encode_audio_wav(audio, args.output_path)


if __name__ == "__main__":
    main()
