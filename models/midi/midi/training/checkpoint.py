"""Checkpoint save/load and layer freezing."""

import torch
from pathlib import Path

from ..model import get_lora_state_dict


def _unwrap_model(model):
    """Unwrap DDP and torch.compile() wrappers to get the raw model."""
    m = model
    if hasattr(m, "module"):  # DDP
        m = m.module
    if hasattr(m, "_orig_mod"):  # torch.compile()
        m = m._orig_mod
    return m


def _strip_compile_prefix(state_dict):
    """Strip _orig_mod. prefix from state dict keys if present."""
    if any(k.startswith("_orig_mod.") for k in state_dict.keys()):
        return {k.replace("_orig_mod.", ""): v for k, v in state_dict.items()}
    return state_dict


def save_checkpoint(model, optimizer, epoch, loss, tokenizer, path, logger=None, scheduler=None):
    """Save model checkpoint."""
    model_to_save = _unwrap_model(model)
    data = {
        "epoch": epoch,
        "model_state_dict": model_to_save.state_dict(),
        "optimizer_state_dict": optimizer.state_dict(),
        "loss": loss,
        "vocab_size": tokenizer.vocab_size,
        "config": {
            "d_model": model_to_save.d_model,
            "n_heads": model_to_save.n_heads,
            "n_layers": model_to_save.n_layers,
            "max_seq_len": model_to_save.max_seq_len,
            "max_tracks": getattr(model_to_save, "max_tracks", None),
            "cross_track_layers": sorted(getattr(model_to_save, "cross_track_layers", [])) or None,
        },
    }
    if scheduler is not None:
        data["scheduler_state_dict"] = scheduler.state_dict()
    torch.save(data, path)
    if logger:
        logger.info(f"Checkpoint saved to {path}")
    else:
        print(f"Checkpoint saved to {path}")


def save_lora_adapter(model, epoch, loss, path, lora_rank, lora_alpha, logger=None):
    """Save only the LoRA adapter weights (small file)."""
    model_to_save = _unwrap_model(model)
    lora_state = get_lora_state_dict(model_to_save)

    torch.save(
        {
            "epoch": epoch,
            "lora_state_dict": lora_state,
            "loss": loss,
            "lora_config": {
                "rank": lora_rank,
                "alpha": lora_alpha,
            },
        },
        path,
    )
    if logger:
        logger.info(f"LoRA adapter saved to {path}")
    else:
        print(f"LoRA adapter saved to {path}")


def load_checkpoint(checkpoint_dir: str, model, optimizer, device, logger=None):
    """
    Load the latest checkpoint to resume training.

    Returns (start_epoch, best_val_loss, scheduler_state_dict_or_None)
    or (1, inf, None) if no checkpoint found.
    """
    checkpoint_path = Path(checkpoint_dir)
    log = logger.info if logger else print

    # Look for the latest epoch checkpoint
    epoch_checkpoints = sorted(
        checkpoint_path.glob("checkpoint_epoch_*.pt"),
        key=lambda p: int(p.stem.split("_")[-1]),
    )
    best_model_path = checkpoint_path / "best_model.pt"

    # Prefer latest epoch checkpoint, fall back to best_model
    if epoch_checkpoints:
        resume_path = epoch_checkpoints[-1]
    elif best_model_path.exists():
        resume_path = best_model_path
    else:
        return 1, float("inf"), None

    log(f"Resuming from checkpoint: {resume_path}")
    checkpoint = torch.load(resume_path, map_location=device, weights_only=False)

    # Load model weights (unwrap DDP/compile, strip prefix for compatibility)
    model_to_load = _unwrap_model(model)
    state_dict = _strip_compile_prefix(checkpoint["model_state_dict"])
    model_to_load.load_state_dict(state_dict)

    # Load optimizer state
    optimizer.load_state_dict(checkpoint["optimizer_state_dict"])

    start_epoch = checkpoint["epoch"] + 1
    best_val_loss = checkpoint["loss"]
    scheduler_state = checkpoint.get("scheduler_state_dict")

    log(f"Resumed from epoch {checkpoint['epoch']} with loss {best_val_loss:.4f}")
    return start_epoch, best_val_loss, scheduler_state


def load_pretrained_checkpoint(checkpoint_path: str, model, device, logger=None):
    """
    Load weights from a pre-trained checkpoint for fine-tuning.

    Unlike load_checkpoint, this:
    - Only loads model weights (not optimizer state)
    - Does not return epoch/loss info (fresh start)
    - Handles torch.compile() prefix stripping
    """
    log = logger.info if logger else print

    log(f"Loading pre-trained weights from: {checkpoint_path}")
    checkpoint = torch.load(checkpoint_path, map_location=device, weights_only=False)

    # Get state dict (strip compile prefix for compatibility)
    state_dict = _strip_compile_prefix(checkpoint["model_state_dict"])
    if state_dict is not checkpoint["model_state_dict"]:
        log("Stripped torch.compile() prefix from state dict")

    # Load into model (unwrap DDP/compile wrappers)
    model_to_load = _unwrap_model(model)
    model_to_load.load_state_dict(state_dict)

    log(f"Loaded pre-trained weights (trained for {checkpoint['epoch']} epochs, loss: {checkpoint['loss']:.4f})")
    return checkpoint


def peek_checkpoint_config(checkpoint_dir_or_path: str) -> dict | None:
    """Read model config from a checkpoint without loading full model weights.

    Args:
        checkpoint_dir_or_path: Checkpoint directory (finds latest) or file path.

    Returns:
        Config dict with d_model, n_heads, n_layers, etc., or None.
    """
    path = Path(checkpoint_dir_or_path)

    if path.is_dir():
        epoch_checkpoints = sorted(
            path.glob("checkpoint_epoch_*.pt"),
            key=lambda p: int(p.stem.split("_")[-1]),
        )
        best_model = path / "best_model.pt"
        if epoch_checkpoints:
            ckpt_path = epoch_checkpoints[-1]
        elif best_model.exists():
            ckpt_path = best_model
        else:
            return None
    elif path.is_file():
        ckpt_path = path
    else:
        return None

    checkpoint = torch.load(ckpt_path, map_location="cpu", weights_only=False)
    return checkpoint.get("config")


def freeze_layers(model, num_layers: int, logger=None):
    """
    Freeze the first N transformer layers of the model.

    Freezing early layers is common in fine-tuning as they capture
    general features, while later layers are more task-specific.
    """
    log = logger.info if logger else print

    model_to_freeze = _unwrap_model(model)

    # Freeze embedding layers (optional - usually good to freeze these too)
    frozen_params = 0

    # Access transformer blocks
    if hasattr(model_to_freeze, "transformer_blocks"):
        blocks = model_to_freeze.transformer_blocks
    elif hasattr(model_to_freeze, "layers"):
        blocks = model_to_freeze.layers
    else:
        log("Warning: Could not find transformer blocks to freeze")
        return

    # Freeze the first N layers
    for i, block in enumerate(blocks[:num_layers]):
        for param in block.parameters():
            param.requires_grad = False
            frozen_params += param.numel()

    total_params = sum(p.numel() for p in model_to_freeze.parameters())
    trainable_params = sum(p.numel() for p in model_to_freeze.parameters() if p.requires_grad)

    log(f"Froze {num_layers} transformer layers ({frozen_params:,} parameters)")
    log(f"Trainable parameters: {trainable_params:,} / {total_params:,} ({100*trainable_params/total_params:.1f}%)")
