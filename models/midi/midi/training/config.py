"""Training configuration."""

import json
from dataclasses import dataclass


def estimate_model_memory_gb(
    d_model: int = 512,
    n_layers: int = 12,
    vocab_size: int = 2000,
    seq_length: int = 8192,
    batch_size: int = 12,
) -> float:
    """Estimate peak training memory in GB.

    Accounts for: model params (fp32) + gradients + optimizer states (Adam 2x)
    + activations for backprop.

    Note: This is an analytical lower bound.  Actual GPU memory is typically
    7-9x higher due to CUDA context, intermediate tensors, memory
    fragmentation, and torch.compile overhead.
    """
    # Parameter count
    embedding_params = vocab_size * d_model
    # Per block: QKV (4*d^2) + FFN (8*d^2) + layernorms (4*d)
    block_params = n_layers * (12 * d_model * d_model + 4 * d_model)
    head_params = d_model * vocab_size + 2 * d_model
    total_params = embedding_params + block_params + head_params

    # params + gradients + Adam momentum + Adam variance = 4x fp32
    model_bytes = total_params * 4 * 4

    # Activation memory per layer: pre-norm + attention output (2 tensors, fp16)
    activation_bytes = n_layers * batch_size * seq_length * d_model * 2 * 2

    # Approximate attention memory (reduced with flash attention)
    attn_bytes = n_layers * batch_size * seq_length * d_model * 2

    total_bytes = model_bytes + activation_bytes + attn_bytes
    return total_bytes / 1e9


# Multiplier that converts the analytical memory estimate to a real-world
# prediction.  Empirically, actual peak GPU memory is 7-9x the analytical
# value (CUDA context, intermediate tensors, fragmentation, torch.compile
# overhead).  We use the low end of the range because the step-up check is
# intentionally optimistic — if memory is tight the batch size can be reduced.
_MEMORY_SAFETY_FACTOR = 7.0


# (max_samples_exclusive, d_model, n_heads, n_layers, tier_label)
_MODEL_SIZE_TIERS = [
    (1_000,  256, 4,  6,  "small"),
    (5_000,  384, 6,  8,  "medium"),
    (20_000, 512, 8,  12, "large"),
    (None,   768, 12, 16, "xlarge"),
]


def compute_model_dims(
    num_training_samples: int,
    available_memory_gb: float | None = None,
    seq_length: int = 8192,
    batch_size: int = 12,
    vocab_size: int = 2000,
) -> dict:
    """Auto-scale model dimensions based on training dataset size and hardware.

    Selects a model tier based on the number of training samples.  When
    *available_memory_gb* is provided and GPU memory can accommodate a larger
    model, the function steps up one tier to avoid under-utilising hardware.

    Returns dict with d_model, n_heads, n_layers, tier, and stepped_up flag.
    """
    # Determine the data-recommended tier
    data_tier_idx = len(_MODEL_SIZE_TIERS) - 1
    for i, (max_samples, *_rest) in enumerate(_MODEL_SIZE_TIERS):
        if max_samples is None or num_training_samples < max_samples:
            data_tier_idx = i
            break

    chosen_idx = data_tier_idx

    # If GPU memory info is available, try stepping up one tier
    if available_memory_gb is not None and data_tier_idx < len(_MODEL_SIZE_TIERS) - 1:
        next_idx = data_tier_idx + 1
        _, next_d, _nh, next_nl, _lbl = _MODEL_SIZE_TIERS[next_idx]
        estimated = estimate_model_memory_gb(
            d_model=next_d,
            n_layers=next_nl,
            vocab_size=vocab_size,
            seq_length=seq_length,
            batch_size=batch_size,
        )
        if estimated * _MEMORY_SAFETY_FACTOR <= available_memory_gb:
            chosen_idx = next_idx

    _, d_model, n_heads, n_layers, label = _MODEL_SIZE_TIERS[chosen_idx]
    return {
        "d_model": d_model,
        "n_heads": n_heads,
        "n_layers": n_layers,
        "tier": label,
        "stepped_up": chosen_idx > data_tier_idx,
    }


@dataclass
class TrainingConfig:
    """Centralized training configuration with sensible defaults."""

    # Model hyperparameters
    d_model: int = 512
    n_heads: int = 8
    n_layers: int = 12
    seq_length: int = 8192

    # Training hyperparameters
    batch_size_per_gpu: int = 12
    gradient_accumulation: int = 4
    learning_rate: float = 3e-4
    learning_rate_finetune: float = 3e-5
    learning_rate_lora: float = 1e-4
    epochs: int = 20
    val_split: float = 0.1
    early_stopping_patience: int = 5
    grad_clip_norm: float = 1.0

    # Regularization
    dropout: float = 0.1
    weight_decay: float = 0.1
    warmup_pct: float = 0.05

    # Scheduler: "cosine" (cosine annealing + linear warmup) or "onecycle" (OneCycleLR)
    scheduler: str = "cosine"

    # Features
    use_tags: bool = True
    use_compile: bool = True

    # Distributed training
    distributed_timeout_minutes: int = 30

    def get_learning_rate(self, is_lora: bool = False, is_finetune: bool = False) -> float:
        """Get appropriate learning rate based on training mode."""
        if is_lora:
            return self.learning_rate_lora
        elif is_finetune:
            return self.learning_rate_finetune
        return self.learning_rate

    @classmethod
    def from_json(cls, path: str) -> "TrainingConfig":
        """Load configuration from a JSON file."""
        with open(path, "r") as f:
            data = json.load(f)

        # Filter out metadata keys (prefixed with underscore)
        config_data = {k: v for k, v in data.items() if not k.startswith("_")}

        # Validate that all keys are known TrainingConfig fields
        import dataclasses
        valid_fields = {field.name for field in dataclasses.fields(cls)}
        unknown_keys = set(config_data.keys()) - valid_fields
        if unknown_keys:
            raise TypeError(
                f"Unknown config keys: {unknown_keys}. "
                f"Valid keys: {sorted(valid_fields)}"
            )

        return cls(**config_data)

    def to_json(self, path: str) -> None:
        """Save current configuration to a JSON file."""
        import dataclasses
        data = dataclasses.asdict(self)
        with open(path, "w") as f:
            json.dump(data, f, indent=4)
