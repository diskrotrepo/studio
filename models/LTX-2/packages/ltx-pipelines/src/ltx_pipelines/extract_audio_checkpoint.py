"""Extract audio-only weights from a full LTX-2 audio-video checkpoint.

Creates a smaller safetensors file containing only the weights needed for
audio-only generation: audio transformer stream, audio VAE decoder, vocoder,
and embeddings processor (audio connector).

Usage:
    python -m ltx_pipelines.extract_audio_checkpoint \
        --input /path/to/full_checkpoint.safetensors \
        --output /path/to/audio_only.safetensors
"""

import argparse
import json
import logging

import safetensors
import safetensors.torch
import torch

logger = logging.getLogger(__name__)

# Key prefixes to keep from the full checkpoint.
# These correspond to the SDOps filters used by AudioOnlyModelLedger.
AUDIO_KEY_PREFIXES = (
    # Audio transformer stream (under model.diffusion_model.audio_*)
    "model.diffusion_model.audio_",
    # Audio transformer blocks (each block has audio_* sub-modules)
    # We keep entire transformer_blocks since they contain shared + audio params;
    # video-only params within blocks will be filtered by strict=False loading.
    "model.diffusion_model.transformer_blocks.",
    # Audio VAE decoder
    "audio_vae.decoder.",
    "audio_vae.per_channel_statistics.",
    # Vocoder (spectrogram -> waveform)
    "vocoder.",
    # Embeddings processor - audio connector and feature extractor
    "model.diffusion_model.audio_embeddings_connector.",
    "text_embedding_projection.audio_aggregate_embed.",
    "text_embedding_projection.aggregate_embed.",
    # Audio caption projection (19B models)
    "model.diffusion_model.audio_caption_projection.",
)

# Key prefixes to explicitly exclude (these match AUDIO_KEY_PREFIXES via
# transformer_blocks but are video-only).
VIDEO_EXCLUDE_PREFIXES = (
    "model.diffusion_model.transformer_blocks.",  # handled by per-key filtering below
)


def _should_keep_key(key: str) -> bool:
    """Determine if a checkpoint key belongs to audio-only components."""
    # Transformer blocks need per-key filtering: keep audio sub-modules, skip video ones
    if key.startswith("model.diffusion_model.transformer_blocks."):
        # Within a block, keep audio-related and shared components
        parts = key.split(".", 4)  # e.g. model.diffusion_model.transformer_blocks.0.rest
        if len(parts) >= 5:
            subkey = parts[4]
            # Keep audio-specific block components
            if subkey.startswith("audio_"):
                return True
            # Skip video-specific block components
            if subkey.startswith("video_"):
                return False
            # Keep shared components (norms, etc.)
            return True
        return True

    # For non-block keys, check against audio prefixes
    for prefix in AUDIO_KEY_PREFIXES:
        if prefix == "model.diffusion_model.transformer_blocks.":
            continue  # handled above
        if key.startswith(prefix):
            return True

    return False


def extract_audio_checkpoint(input_path: str, output_path: str) -> None:
    """Read a full AV checkpoint and write an audio-only subset."""
    logger.info(f"Reading checkpoint: {input_path}")

    # Read metadata
    metadata = {}
    with safetensors.safe_open(input_path, framework="pt") as f:
        meta = f.metadata()
        if meta is not None:
            metadata = dict(meta)
        all_keys = list(f.keys())

    # Filter keys
    audio_keys = [k for k in all_keys if _should_keep_key(k)]
    skipped_keys = len(all_keys) - len(audio_keys)
    logger.info(f"Keeping {len(audio_keys)} / {len(all_keys)} keys (skipping {skipped_keys} video-only keys)")

    # Load only the audio tensors
    tensors = {}
    with safetensors.safe_open(input_path, framework="pt", device="cpu") as f:
        for key in audio_keys:
            tensors[key] = f.get_tensor(key)

    # Compute size reduction
    total_params = sum(t.numel() for t in tensors.values())
    total_bytes = sum(t.nbytes for t in tensors.values())
    logger.info(f"Audio-only checkpoint: {total_params:,} parameters, {total_bytes / 1e9:.2f} GB")

    # Save with metadata preserved
    safetensors.torch.save_file(tensors, output_path, metadata=metadata)
    logger.info(f"Saved audio-only checkpoint to: {output_path}")


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    parser = argparse.ArgumentParser(
        description="Extract audio-only weights from a full LTX-2 checkpoint.",
    )
    parser.add_argument(
        "--input",
        type=str,
        required=True,
        help="Path to the full AV checkpoint (.safetensors).",
    )
    parser.add_argument(
        "--output",
        type=str,
        required=True,
        help="Path to write the audio-only checkpoint (.safetensors).",
    )
    args = parser.parse_args()
    extract_audio_checkpoint(args.input, args.output)


if __name__ == "__main__":
    main()
