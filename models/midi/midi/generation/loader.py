import torch
import logging

from ..model import (
    MusicTransformer,
    MultiTrackMusicTransformer,
    enable_lora,
    load_lora_state_dict,
)
from ..tokenization import MAX_TRACKS

logger = logging.getLogger(__name__)


def load_model(checkpoint_path: str, device: torch.device, lora_adapter_path: str = None, dtype: torch.dtype = None):
    """
    Load a trained model from checkpoint, optionally with a LoRA adapter.

    Args:
        checkpoint_path: Path to base model checkpoint
        device: Device to load model to
        lora_adapter_path: Optional path to LoRA adapter file
    """
    try:
        logger.info(f"Loading model from {checkpoint_path}")
        checkpoint = torch.load(checkpoint_path, map_location=device, weights_only=False)

        config = checkpoint["config"]
        vocab_size = checkpoint["vocab_size"]

        # Auto-detect multitrack checkpoints (check config, then fall back to state_dict keys)
        state_dict = checkpoint["model_state_dict"]
        is_multitrack = config.get("max_tracks") is not None or any(
            "self_attn" in k or "cross_attn" in k or "track_emb" in k for k in state_dict.keys()
        )
        if is_multitrack:
            logger.info("Detected multi-track checkpoint, using MultiTrackMusicTransformer")
            model = MultiTrackMusicTransformer(
                vocab_size=vocab_size,
                d_model=config["d_model"],
                n_heads=config["n_heads"],
                n_layers=config["n_layers"],
                max_seq_len=config["max_seq_len"],
                max_tracks=config.get("max_tracks", MAX_TRACKS),
                cross_track_layers=config.get("cross_track_layers"),
            ).to(device)
        else:
            model = MusicTransformer(
                vocab_size=vocab_size,
                d_model=config["d_model"],
                n_heads=config["n_heads"],
                n_layers=config["n_layers"],
                max_seq_len=config["max_seq_len"],
            ).to(device)

        # Handle state dict from torch.compile() wrapped models
        if any(k.startswith("_orig_mod.") for k in state_dict.keys()):
            state_dict = {k.replace("_orig_mod.", ""): v for k, v in state_dict.items()}
            logger.info("Stripped _orig_mod. prefix from compiled model state dict")

        model.load_state_dict(state_dict)

        # Load LoRA adapter if provided
        if lora_adapter_path:
            logger.info(f"Loading LoRA adapter from {lora_adapter_path}")
            lora_checkpoint = torch.load(lora_adapter_path, map_location=device, weights_only=False)
            lora_config = lora_checkpoint["lora_config"]

            # Enable LoRA with same config used during training
            enable_lora(model, rank=lora_config["rank"], alpha=lora_config["alpha"])

            # Load the trained adapter weights
            load_lora_state_dict(model, lora_checkpoint["lora_state_dict"])
            logger.info(f"LoRA adapter loaded (rank={lora_config['rank']}, alpha={lora_config['alpha']})")

        model.eval()

        if dtype:
            model = model.to(dtype=dtype)
            logger.info(f"Model cast to {dtype}")

        # Compile model for faster inference (graph optimization + kernel fusion)
        try:
            model = torch.compile(model)
            logger.info("Model compiled with torch.compile()")
        except Exception as e:
            logger.warning(f"torch.compile() failed, using eager mode: {e}")

        logger.info(f"Model loaded successfully (vocab_size={vocab_size}, d_model={config['d_model']})")
        return model
    except Exception as e:
        logger.exception(f"Failed to load model from {checkpoint_path}: {e}")
        raise


def load_multitrack_model(checkpoint_path: str, device: torch.device, lora_adapter_path: str = None, dtype: torch.dtype = None):
    """
    Load a trained multi-track model from checkpoint, optionally with a LoRA adapter.

    Args:
        checkpoint_path: Path to base model checkpoint
        device: Device to load model to
        lora_adapter_path: Optional path to LoRA adapter file
    """
    checkpoint = torch.load(checkpoint_path, map_location=device, weights_only=False)

    config = checkpoint["config"]
    vocab_size = checkpoint["vocab_size"]

    # Check if this is a multi-track model
    is_multitrack = config.get("max_tracks") is not None

    if is_multitrack:
        model = MultiTrackMusicTransformer(
            vocab_size=vocab_size,
            d_model=config["d_model"],
            n_heads=config["n_heads"],
            n_layers=config["n_layers"],
            max_seq_len=config["max_seq_len"],
            max_tracks=config.get("max_tracks", MAX_TRACKS),
            cross_track_layers=config.get("cross_track_layers"),
        ).to(device)
    else:
        # Load as multi-track but initialize from single-track weights
        model = MultiTrackMusicTransformer(
            vocab_size=vocab_size,
            d_model=config["d_model"],
            n_heads=config["n_heads"],
            n_layers=config["n_layers"],
            max_seq_len=config["max_seq_len"],
            max_tracks=MAX_TRACKS,
        ).to(device)
        model.load_single_track_weights(checkpoint_path, device)
        print("Loaded single-track weights into multi-track model")

        # Load LoRA adapter if provided
        if lora_adapter_path:
            logger.info(f"Loading LoRA adapter from {lora_adapter_path}")
            lora_checkpoint = torch.load(lora_adapter_path, map_location=device, weights_only=False)
            lora_config = lora_checkpoint["lora_config"]
            enable_lora(model, rank=lora_config["rank"], alpha=lora_config["alpha"])
            load_lora_state_dict(model, lora_checkpoint["lora_state_dict"])
            logger.info(f"LoRA adapter loaded (rank={lora_config['rank']}, alpha={lora_config['alpha']})")

        model.eval()

        if dtype:
            model = model.to(dtype=dtype)
            logger.info(f"Model cast to {dtype}")

        if device.type in ("cuda", "mps"):
            try:
                model = torch.compile(model)
                logger.info("Model compiled with torch.compile()")
            except Exception as e:
                logger.warning(f"torch.compile() failed, using eager mode: {e}")

        return model

    # Handle state dict from torch.compile() wrapped models
    state_dict = checkpoint["model_state_dict"]
    if any(k.startswith("_orig_mod.") for k in state_dict.keys()):
        state_dict = {k.replace("_orig_mod.", ""): v for k, v in state_dict.items()}

    model.load_state_dict(state_dict)

    # Load LoRA adapter if provided
    if lora_adapter_path:
        logger.info(f"Loading LoRA adapter from {lora_adapter_path}")
        lora_checkpoint = torch.load(lora_adapter_path, map_location=device, weights_only=False)
        lora_config = lora_checkpoint["lora_config"]
        enable_lora(model, rank=lora_config["rank"], alpha=lora_config["alpha"])
        load_lora_state_dict(model, lora_checkpoint["lora_state_dict"])
        logger.info(f"LoRA adapter loaded (rank={lora_config['rank']}, alpha={lora_config['alpha']})")

    model.eval()

    if dtype:
        model = model.to(dtype=dtype)
        logger.info(f"Model cast to {dtype}")

    if device.type in ("cuda", "mps"):
        try:
            model = torch.compile(model)
            logger.info("Model compiled with torch.compile()")
        except Exception as e:
            logger.warning(f"torch.compile() failed, using eager mode: {e}")

    return model
