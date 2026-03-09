from dataclasses import replace

import torch

from ltx_core.loader import SDOps
from ltx_core.loader.primitives import LoraPathStrengthAndSDOps
from ltx_core.loader.registry import DummyRegistry, Registry, StateDictRegistry
from ltx_core.loader.single_gpu_model_builder import SingleGPUModelBuilder as Builder
from ltx_core.model.audio_vae import (
    AUDIO_VAE_DECODER_COMFY_KEYS_FILTER,
    AUDIO_VAE_ENCODER_COMFY_KEYS_FILTER,
    VOCODER_COMFY_KEYS_FILTER,
    AudioDecoder,
    AudioDecoderConfigurator,
    AudioEncoder,
    AudioEncoderConfigurator,
    Vocoder,
    VocoderConfigurator,
)
from ltx_core.model.transformer import (
    LTXV_MODEL_COMFY_RENAMING_MAP,
    LTXAudioOnlyModelConfigurator,
    LTXModelConfigurator,
    X0Model,
)
from ltx_core.model.upsampler import LatentUpsampler, LatentUpsamplerConfigurator
from ltx_core.model.video_vae import (
    VAE_DECODER_COMFY_KEYS_FILTER,
    VAE_ENCODER_COMFY_KEYS_FILTER,
    VideoDecoder,
    VideoDecoderConfigurator,
    VideoEncoder,
    VideoEncoderConfigurator,
)
from ltx_core.quantization import QuantizationPolicy
from ltx_core.text_encoders.gemma import (
    AUDIO_ONLY_EMBEDDINGS_PROCESSOR_KEY_OPS,
    EMBEDDINGS_PROCESSOR_KEY_OPS,
    GEMMA_LLM_KEY_OPS,
    GEMMA_MODEL_OPS,
    AudioOnlyEmbeddingsProcessorConfigurator,
    EmbeddingsProcessor,
    EmbeddingsProcessorConfigurator,
    GemmaTextEncoder,
    GemmaTextEncoderConfigurator,
    module_ops_from_gemma_root,
)
from ltx_core.utils import find_matching_file


class ModelLedger:
    """
    Central coordinator for loading and building models used in an LTX pipeline.
    The ledger wires together multiple model builders (transformer, video VAE encoder/decoder,
    audio VAE decoder, vocoder, text encoder, and optional latent upsampler) and exposes
    factory methods for constructing model instances.
    ### Model Building
    Each model method (e.g. :meth:`transformer`, :meth:`video_decoder`, :meth:`text_encoder`)
    constructs a new model instance on each call. The builder uses the
    :class:`~ltx_core.loader.registry.Registry` to load weights from the checkpoint,
    instantiates the model with the configured ``dtype``, and moves it to ``self.device``.
    .. note::
        Models are **cached** after first construction. Subsequent calls to the same
        model method return the cached instance. Use :meth:`release_model` or
        :meth:`release_all_models` to free cached models and reclaim GPU memory.
    ### Constructor parameters
    dtype:
        Torch dtype used when constructing all models (e.g. ``torch.bfloat16``).
    device:
        Target device to which models are moved after construction (e.g. ``torch.device("cuda")``).
    checkpoint_path:
        Path to a checkpoint directory or file containing the core model weights
        (transformer, video VAE, audio VAE, text encoder, vocoder). If ``None``, the
        corresponding builders are not created and calling those methods will raise
        a :class:`ValueError`.
    gemma_root_path:
        Base path to Gemma-compatible CLIP/text encoder weights. Required to
        initialize the text encoder builder; if omitted, :meth:`text_encoder` cannot be used.
    spatial_upsampler_path:
        Optional path to a latent upsampler checkpoint. If provided, the
        :meth:`spatial_upsampler` method becomes available; otherwise calling it raises
        a :class:`ValueError`.
    loras:
        Tuple of LoRA configurations (path, strength, sd_ops) applied on top of the base
        transformer weights. Use ``()`` for none.
    registry:
        Optional :class:`Registry` instance for weight caching across builders.
        Defaults to :class:`DummyRegistry` which performs no cross-builder caching.
    quantization:
        Optional :class:`QuantizationPolicy` controlling how transformer weights
        are stored and how matmul is executed. Defaults to None, which means no quantization.
    ### Creating Variants
    Use :meth:`with_additional_loras` to create a new ``ModelLedger`` instance that
    includes additional LoRA configurations or :meth:`with_loras` to replace existing
    lora configurations while sharing the same registry for weight caching.
    """

    def __init__(
        self,
        dtype: torch.dtype,
        device: torch.device,
        checkpoint_path: str | None = None,
        gemma_root_path: str | None = None,
        spatial_upsampler_path: str | None = None,
        loras: tuple[LoraPathStrengthAndSDOps, ...] = (),
        registry: Registry | None = None,
        quantization: QuantizationPolicy | None = None,
    ):
        self.dtype = dtype
        self.device = device
        self.checkpoint_path = checkpoint_path
        self.gemma_root_path = gemma_root_path
        self.spatial_upsampler_path = spatial_upsampler_path
        self.loras = loras
        self.registry = registry or StateDictRegistry()
        self.quantization = quantization
        self._model_cache: dict[str, object] = {}
        self.build_model_builders()

    def build_model_builders(self) -> None:
        if self.checkpoint_path is not None:
            self.transformer_builder = Builder(
                model_path=self.checkpoint_path,
                model_class_configurator=LTXModelConfigurator,
                model_sd_ops=LTXV_MODEL_COMFY_RENAMING_MAP,
                loras=tuple(self.loras),
                registry=self.registry,
            )

            self.vae_decoder_builder = Builder(
                model_path=self.checkpoint_path,
                model_class_configurator=VideoDecoderConfigurator,
                model_sd_ops=VAE_DECODER_COMFY_KEYS_FILTER,
                registry=self.registry,
            )

            self.vae_encoder_builder = Builder(
                model_path=self.checkpoint_path,
                model_class_configurator=VideoEncoderConfigurator,
                model_sd_ops=VAE_ENCODER_COMFY_KEYS_FILTER,
                registry=self.registry,
            )

            self.audio_encoder_builder = Builder[AudioEncoder](
                model_path=self.checkpoint_path,
                model_class_configurator=AudioEncoderConfigurator,
                model_sd_ops=AUDIO_VAE_ENCODER_COMFY_KEYS_FILTER,
                registry=self.registry,
            )

            self.audio_decoder_builder = Builder(
                model_path=self.checkpoint_path,
                model_class_configurator=AudioDecoderConfigurator,
                model_sd_ops=AUDIO_VAE_DECODER_COMFY_KEYS_FILTER,
                registry=self.registry,
            )

            self.vocoder_builder = Builder(
                model_path=self.checkpoint_path,
                model_class_configurator=VocoderConfigurator,
                model_sd_ops=VOCODER_COMFY_KEYS_FILTER,
                registry=self.registry,
            )

            # Embeddings processor only needs the LTX checkpoint (no Gemma weights)
            self.embeddings_processor_builder = Builder(
                model_path=self.checkpoint_path,
                model_class_configurator=EmbeddingsProcessorConfigurator,
                model_sd_ops=EMBEDDINGS_PROCESSOR_KEY_OPS,
                registry=self.registry,
            )

            if self.gemma_root_path is not None:
                module_ops = module_ops_from_gemma_root(self.gemma_root_path)
                model_folder = find_matching_file(self.gemma_root_path, "model*.safetensors").parent
                weight_paths = [str(p) for p in model_folder.rglob("*.safetensors")]

                self.text_encoder_builder = Builder(
                    model_path=tuple(weight_paths),
                    model_class_configurator=GemmaTextEncoderConfigurator,
                    model_sd_ops=GEMMA_LLM_KEY_OPS,
                    registry=self.registry,
                    module_ops=(GEMMA_MODEL_OPS, *module_ops),
                )

        if self.spatial_upsampler_path is not None:
            self.upsampler_builder = Builder(
                model_path=self.spatial_upsampler_path,
                model_class_configurator=LatentUpsamplerConfigurator,
                registry=self.registry,
            )

    def _target_device(self) -> torch.device:
        if isinstance(self.registry, DummyRegistry) or self.registry is None:
            return self.device
        else:
            return torch.device("cpu")

    def release_model(self, key: str) -> None:
        """Remove a cached model, freeing its GPU memory."""
        self._model_cache.pop(key, None)

    def release_all_models(self) -> None:
        """Remove all cached models."""
        self._model_cache.clear()

    def with_additional_loras(self, loras: tuple[LoraPathStrengthAndSDOps, ...]) -> "ModelLedger":
        """Add new lora configurations to the existing ones."""
        return self.with_loras((*self.loras, *loras))

    def with_loras(self, loras: tuple[LoraPathStrengthAndSDOps, ...]) -> "ModelLedger":
        """Replace existing lora configurations with new ones."""
        return ModelLedger(
            dtype=self.dtype,
            device=self.device,
            checkpoint_path=self.checkpoint_path,
            gemma_root_path=self.gemma_root_path,
            spatial_upsampler_path=self.spatial_upsampler_path,
            loras=loras,
            registry=self.registry,
            quantization=self.quantization,
        )

    def transformer(self) -> X0Model:
        if "transformer" in self._model_cache:
            return self._model_cache["transformer"]

        if not hasattr(self, "transformer_builder"):
            raise ValueError(
                "Transformer not initialized. Please provide a checkpoint path to the ModelLedger constructor."
            )

        if self.quantization is None:
            velocity_model = self.transformer_builder.build(device=self._target_device(), dtype=self.dtype)
        else:
            sd_ops = self.transformer_builder.model_sd_ops
            if self.quantization.sd_ops is not None:
                sd_ops = SDOps(
                    name=f"sd_ops_chain_{sd_ops.name}+{self.quantization.sd_ops.name}",
                    mapping=(*sd_ops.mapping, *self.quantization.sd_ops.mapping),
                )
            builder = replace(
                self.transformer_builder,
                module_ops=(*self.transformer_builder.module_ops, *self.quantization.module_ops),
                model_sd_ops=sd_ops,
            )
            velocity_model = builder.build(device=self._target_device())

        velocity_model = velocity_model.to(self.device).eval()
        model = X0Model(velocity_model)

        self._model_cache["transformer"] = model
        return model

    def video_decoder(self) -> VideoDecoder:
        if "video_decoder" in self._model_cache:
            return self._model_cache["video_decoder"]

        if not hasattr(self, "vae_decoder_builder"):
            raise ValueError(
                "Video decoder not initialized. Please provide a checkpoint path to the ModelLedger constructor."
            )

        model = self.vae_decoder_builder.build(device=self._target_device(), dtype=self.dtype).to(self.device).eval()
        self._model_cache["video_decoder"] = model
        return model

    def video_encoder(self) -> VideoEncoder:
        if "video_encoder" in self._model_cache:
            return self._model_cache["video_encoder"]

        if not hasattr(self, "vae_encoder_builder"):
            raise ValueError(
                "Video encoder not initialized. Please provide a checkpoint path to the ModelLedger constructor."
            )

        model = self.vae_encoder_builder.build(device=self._target_device(), dtype=self.dtype).to(self.device).eval()
        self._model_cache["video_encoder"] = model
        return model

    def text_encoder(self) -> GemmaTextEncoder:
        if "text_encoder" in self._model_cache:
            return self._model_cache["text_encoder"]

        if not hasattr(self, "text_encoder_builder"):
            raise ValueError(
                "Text encoder not initialized. Please provide a checkpoint path and gemma root path to the "
                "ModelLedger constructor."
            )

        model = self.text_encoder_builder.build(device=self._target_device(), dtype=self.dtype).to(self.device).eval()
        self._model_cache["text_encoder"] = model
        return model

    def gemma_embeddings_processor(self) -> EmbeddingsProcessor:
        if "embeddings_processor" in self._model_cache:
            return self._model_cache["embeddings_processor"]

        if not hasattr(self, "embeddings_processor_builder"):
            raise ValueError(
                "Embeddings processor not initialized. Please provide a checkpoint path to the ModelLedger constructor."
            )

        model = (
            self.embeddings_processor_builder.build(device=self._target_device(), dtype=self.dtype)
            .to(self.device)
            .eval()
        )
        self._model_cache["embeddings_processor"] = model
        return model

    def audio_encoder(self) -> AudioEncoder:
        if "audio_encoder" in self._model_cache:
            return self._model_cache["audio_encoder"]

        if not hasattr(self, "audio_encoder_builder"):
            raise ValueError(
                "Audio encoder not initialized. Please provide a checkpoint path to the ModelLedger constructor."
            )

        model = self.audio_encoder_builder.build(device=self._target_device(), dtype=self.dtype).to(self.device).eval()
        self._model_cache["audio_encoder"] = model
        return model

    def audio_decoder(self) -> AudioDecoder:
        if "audio_decoder" in self._model_cache:
            return self._model_cache["audio_decoder"]

        if not hasattr(self, "audio_decoder_builder"):
            raise ValueError(
                "Audio decoder not initialized. Please provide a checkpoint path to the ModelLedger constructor."
            )

        model = self.audio_decoder_builder.build(device=self._target_device(), dtype=self.dtype).to(self.device).eval()
        self._model_cache["audio_decoder"] = model
        return model

    def vocoder(self) -> Vocoder:
        if "vocoder" in self._model_cache:
            return self._model_cache["vocoder"]

        if not hasattr(self, "vocoder_builder"):
            raise ValueError(
                "Vocoder not initialized. Please provide a checkpoint path to the ModelLedger constructor."
            )

        model = self.vocoder_builder.build(device=self._target_device(), dtype=self.dtype).to(self.device).eval()
        self._model_cache["vocoder"] = model
        return model

    def spatial_upsampler(self) -> LatentUpsampler:
        if "spatial_upsampler" in self._model_cache:
            return self._model_cache["spatial_upsampler"]

        if not hasattr(self, "upsampler_builder"):
            raise ValueError("Upsampler not initialized. Please provide upsampler path to the ModelLedger constructor.")

        model = self.upsampler_builder.build(device=self._target_device(), dtype=self.dtype).to(self.device).eval()
        self._model_cache["spatial_upsampler"] = model
        return model


class AudioOnlyModelLedger(ModelLedger):
    """
    Model ledger for audio-only generation.
    Only creates builders for the audio-related components: transformer (audio-only),
    audio decoder, vocoder, embeddings processor, and text encoder.
    Skips video VAE encoder/decoder, audio encoder, and spatial upsampler.
    """

    def __init__(
        self,
        dtype: torch.dtype,
        device: torch.device,
        checkpoint_path: str | None = None,
        gemma_root_path: str | None = None,
        loras: tuple[LoraPathStrengthAndSDOps, ...] = (),
        registry: Registry | None = None,
        quantization: QuantizationPolicy | None = None,
        gemma_4bit: bool = False,
    ):
        # Skip ModelLedger.__init__ to avoid building video builders,
        # call grandparent init directly and then build our own builders.
        self.dtype = dtype
        self.device = device
        self.checkpoint_path = checkpoint_path
        self.gemma_root_path = gemma_root_path
        self.spatial_upsampler_path = None
        self.loras = loras
        self.registry = registry or StateDictRegistry()
        self.quantization = quantization
        self.gemma_4bit = gemma_4bit
        self._model_cache: dict[str, object] = {}
        self.build_model_builders()

    def build_model_builders(self) -> None:
        if self.checkpoint_path is not None:
            self.transformer_builder = Builder(
                model_path=self.checkpoint_path,
                model_class_configurator=LTXAudioOnlyModelConfigurator,
                model_sd_ops=LTXV_MODEL_COMFY_RENAMING_MAP,
                loras=tuple(self.loras),
                registry=self.registry,
            )

            self.audio_decoder_builder = Builder(
                model_path=self.checkpoint_path,
                model_class_configurator=AudioDecoderConfigurator,
                model_sd_ops=AUDIO_VAE_DECODER_COMFY_KEYS_FILTER,
                registry=self.registry,
            )

            self.vocoder_builder = Builder(
                model_path=self.checkpoint_path,
                model_class_configurator=VocoderConfigurator,
                model_sd_ops=VOCODER_COMFY_KEYS_FILTER,
                registry=self.registry,
            )

            self.embeddings_processor_builder = Builder(
                model_path=self.checkpoint_path,
                model_class_configurator=AudioOnlyEmbeddingsProcessorConfigurator,
                model_sd_ops=AUDIO_ONLY_EMBEDDINGS_PROCESSOR_KEY_OPS,
                registry=self.registry,
            )

            if self.gemma_root_path is not None and not self.gemma_4bit:
                module_ops = module_ops_from_gemma_root(self.gemma_root_path)
                model_folder = find_matching_file(self.gemma_root_path, "model*.safetensors").parent
                weight_paths = [str(p) for p in model_folder.rglob("*.safetensors")]

                self.text_encoder_builder = Builder(
                    model_path=tuple(weight_paths),
                    model_class_configurator=GemmaTextEncoderConfigurator,
                    model_sd_ops=GEMMA_LLM_KEY_OPS,
                    registry=self.registry,
                    module_ops=(GEMMA_MODEL_OPS, *module_ops),
                )

    def text_encoder(self) -> GemmaTextEncoder:
        if "text_encoder" in self._model_cache:
            return self._model_cache["text_encoder"]

        if self.gemma_4bit and self.gemma_root_path is not None:
            from ltx_core.text_encoders.gemma.encoders.base_encoder import load_4bit_gemma  # noqa: PLC0415

            model = load_4bit_gemma(self.gemma_root_path, dtype=self.dtype)
            self._model_cache["text_encoder"] = model
            return model

        return super().text_encoder()

    def with_loras(self, loras: tuple[LoraPathStrengthAndSDOps, ...]) -> "AudioOnlyModelLedger":
        return AudioOnlyModelLedger(
            dtype=self.dtype,
            device=self.device,
            checkpoint_path=self.checkpoint_path,
            gemma_root_path=self.gemma_root_path,
            loras=loras,
            registry=self.registry,
            quantization=self.quantization,
            gemma_4bit=self.gemma_4bit,
        )
