"""
Model Quantization via Core ML

Converts PyTorch checkpoints to quantized Core ML .mlpackage files.
Supports float16, int8, and palette-based quantization.

Usage:
    python -m midi.quantize --checkpoint checkpoints/best_model.pt
    python -m midi.quantize --checkpoint checkpoints/best_model.pt --quantization int8
"""

import argparse
import logging
import math
from pathlib import Path

import coremltools as ct
import coremltools.optimize.coreml as cto
import numpy as np
import torch
import torch.nn as nn

logger = logging.getLogger(__name__)

QUANTIZATION_CHOICES = ["float16", "int8", "palettize4", "palettize6"]


class _SingleTrackWrapper(nn.Module):
    """Wraps MusicTransformer for tracing (no KV-cache, no conditionals)."""

    def __init__(self, model):
        super().__init__()
        self.model = model

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.model(x, past_kv=None, use_cache=False)


class _MultiTrackWrapper(nn.Module):
    """Wraps MultiTrackMusicTransformer for tracing (no KV-cache, no conditionals)."""

    def __init__(self, model):
        super().__init__()
        self.model = model

    def forward(
        self, x: torch.Tensor, track_ids: torch.Tensor, cross_track_mask: torch.Tensor
    ) -> torch.Tensor:
        return self.model(
            x,
            track_ids=track_ids,
            cross_track_mask=cross_track_mask,
            past_kv=None,
            use_cache=False,
        )


class _SingleTrackCausalMaskWrapper(nn.Module):
    """Fallback wrapper that replaces is_causal=True with an explicit mask.

    Used if tracing with is_causal=True fails during coremltools conversion.
    """

    def __init__(self, model):
        super().__init__()
        self.model = model
        self._patch_attention_modules()

    def _patch_attention_modules(self):
        """Replace is_causal=True SDPA calls with explicit causal masks."""
        from .model.layers import MultiHeadAttention

        for module in self.model.modules():
            if isinstance(module, MultiHeadAttention):
                module._original_forward = module.forward
                module.forward = self._make_explicit_causal_forward(module)

    @staticmethod
    def _make_explicit_causal_forward(attn_module):
        def forward(x, mask=None, past_kv=None, use_cache=False):
            batch_size, seq_len, _ = x.shape

            qkv = attn_module.qkv_proj(x)
            qkv = qkv.reshape(batch_size, seq_len, 3, attn_module.n_heads, attn_module.head_dim)
            qkv = qkv.permute(2, 0, 3, 1, 4)
            q, k, v = qkv[0], qkv[1], qkv[2]

            # Explicit causal mask instead of is_causal=True
            causal_mask = torch.triu(
                torch.full((seq_len, seq_len), float("-inf"), dtype=q.dtype, device=q.device),
                diagonal=1,
            )
            out = torch.nn.functional.scaled_dot_product_attention(
                q, k, v, attn_mask=causal_mask, dropout_p=0.0, is_causal=False,
            )

            out = out.transpose(1, 2).reshape(batch_size, seq_len, attn_module.d_model)
            out = attn_module.out_proj(out)
            return out

        return forward

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.model(x, past_kv=None, use_cache=False)


def quantize(
    checkpoint_path: str,
    output_path: str = None,
    quantization: str = "float16",
    lora_adapter_path: str = None,
) -> str:
    """
    Quantize a PyTorch checkpoint to a Core ML .mlpackage.

    Args:
        checkpoint_path: Path to .pt model checkpoint
        output_path: Output .mlpackage path (auto-generated if None)
        quantization: One of "float16", "int8", "palettize4", "palettize6"
        lora_adapter_path: Optional LoRA adapter to merge before quantization

    Returns:
        Path to the saved .mlpackage file
    """
    from .generation.loader import load_model
    from .model import MultiTrackMusicTransformer, LoRALinear, disable_lora

    if quantization not in QUANTIZATION_CHOICES:
        raise ValueError(
            f"Unknown quantization '{quantization}'. Choose from: {QUANTIZATION_CHOICES}"
        )

    # Load model on CPU for conversion
    device = torch.device("cpu")
    logger.info(f"Loading checkpoint from {checkpoint_path}")
    model = load_model(checkpoint_path, device, lora_adapter_path=lora_adapter_path)

    # Merge LoRA weights if present
    has_lora = any(isinstance(m, LoRALinear) for m in model.modules())
    if has_lora:
        logger.info("Merging LoRA weights into base model")
        disable_lora(model, merge=True)

    model.eval()
    is_multitrack = isinstance(model, MultiTrackMusicTransformer)
    model_type = "multitrack" if is_multitrack else "single-track"
    logger.info(f"Model type: {model_type}, vocab_size={model.vocab_size}, d_model={model.d_model}")

    # Create wrapper and example inputs for tracing
    example_seq_len = 128
    if is_multitrack:
        wrapper = _MultiTrackWrapper(model)
        example_inputs = (
            torch.randint(0, model.vocab_size, (1, example_seq_len)),
            torch.zeros(1, example_seq_len, dtype=torch.long),
            torch.ones(1, example_seq_len, example_seq_len, dtype=torch.bool).tril(),
        )
    else:
        wrapper = _SingleTrackWrapper(model)
        example_inputs = (torch.randint(0, model.vocab_size, (1, example_seq_len)),)

    # Trace the model
    logger.info("Tracing model with torch.jit.trace")
    with torch.no_grad():
        traced = torch.jit.trace(wrapper, example_inputs)

    # Define input shapes with dynamic sequence length
    max_seq_len = model.max_seq_len
    seq_range = ct.RangeDim(lower_bound=1, upper_bound=max_seq_len, default=example_seq_len)

    if is_multitrack:
        ct_inputs = [
            ct.TensorType(name="token_ids", shape=(1, seq_range), dtype=np.int32),
            ct.TensorType(name="track_ids", shape=(1, seq_range), dtype=np.int32),
            ct.TensorType(
                name="cross_track_mask",
                shape=(1, ct.RangeDim(1, max_seq_len, example_seq_len),
                       ct.RangeDim(1, max_seq_len, example_seq_len)),
            ),
        ]
    else:
        ct_inputs = [
            ct.TensorType(name="token_ids", shape=(1, seq_range), dtype=np.int32),
        ]

    # Convert to Core ML
    precision = ct.precision.FLOAT16 if quantization == "float16" else ct.precision.FLOAT32
    logger.info(f"Converting to Core ML (precision={precision})")

    try:
        ml_model = _convert_to_coreml(ct, traced, ct_inputs, precision)
    except Exception as e:
        if not is_multitrack and "causal" in str(e).lower() or "is_causal" in str(e).lower():
            logger.warning(f"Conversion failed with is_causal=True: {e}")
            logger.info("Retrying with explicit causal mask fallback")
            wrapper = _SingleTrackCausalMaskWrapper(model)
            with torch.no_grad():
                traced = torch.jit.trace(wrapper, example_inputs)
            ml_model = _convert_to_coreml(ct, traced, ct_inputs, precision)
        else:
            raise

    # Apply post-conversion quantization
    if quantization == "int8":
        logger.info("Applying int8 linear quantization")
        op_config = cto.OpLinearQuantizerConfig(
            mode="linear_symmetric",
            dtype="int8",
            weight_threshold=512,
        )
        config = cto.OptimizationConfig(global_config=op_config)
        ml_model = cto.linear_quantize_weights(ml_model, config=config)

    elif quantization.startswith("palettize"):
        nbits = int(quantization.replace("palettize", ""))
        logger.info(f"Applying {nbits}-bit palette quantization")
        op_config = cto.OpPalettizerConfig(
            nbits=nbits,
            mode="kmeans",
            weight_threshold=512,
        )
        config = cto.OptimizationConfig(global_config=op_config)
        ml_model = cto.palettize_weights(ml_model, config=config)

    # Set metadata
    ml_model.author = "MIDI Music Generator"
    ml_model.short_description = f"Music Transformer ({model_type}, {quantization})"

    # Determine output path
    if output_path is None:
        stem = Path(checkpoint_path).stem
        output_path = str(Path(checkpoint_path).parent / f"{stem}_{quantization}.mlpackage")

    logger.info(f"Saving to {output_path}")
    ml_model.save(output_path)

    # Report sizes
    orig_size = Path(checkpoint_path).stat().st_size / (1024 * 1024)
    # mlpackage is a directory; sum contents
    pkg_path = Path(output_path)
    if pkg_path.is_dir():
        new_size = sum(f.stat().st_size for f in pkg_path.rglob("*") if f.is_file()) / (1024 * 1024)
    else:
        new_size = pkg_path.stat().st_size / (1024 * 1024)

    logger.info(f"Original: {orig_size:.1f} MB -> Quantized: {new_size:.1f} MB ({new_size/orig_size:.1%})")

    return output_path


def _convert_to_coreml(ct, traced_model, inputs, precision):
    """Run coremltools conversion."""
    return ct.convert(
        traced_model,
        inputs=inputs,
        convert_to="mlprogram",
        compute_precision=precision,
        minimum_deployment_target=ct.target.macOS13,
    )


def main():
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(levelname)s - %(message)s",
    )

    parser = argparse.ArgumentParser(description="Quantize a MIDI model to Core ML")
    parser.add_argument(
        "--checkpoint",
        type=str,
        required=True,
        help="Path to model checkpoint (.pt)",
    )
    parser.add_argument(
        "--quantization",
        type=str,
        default="float16",
        choices=QUANTIZATION_CHOICES,
        help="Quantization mode (default: float16)",
    )
    parser.add_argument(
        "--lora-adapter",
        type=str,
        default=None,
        help="Path to LoRA adapter to merge before quantization",
    )
    parser.add_argument(
        "--output",
        type=str,
        default=None,
        help="Output .mlpackage path (default: auto from checkpoint name)",
    )

    args = parser.parse_args()

    if not Path(args.checkpoint).exists():
        print(f"Error: Checkpoint not found at {args.checkpoint}")
        return

    output = quantize(
        checkpoint_path=args.checkpoint,
        output_path=args.output,
        quantization=args.quantization,
        lora_adapter_path=args.lora_adapter,
    )
    print(f"Quantized model saved to {output}")


if __name__ == "__main__":
    main()
