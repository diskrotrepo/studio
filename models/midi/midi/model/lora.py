"""
LoRA (Low-Rank Adaptation) Components

Efficient fine-tuning by adding trainable low-rank matrices to frozen linear layers.
"""

import math
import torch
import torch.nn as nn


class LoRALinear(nn.Module):
    """
    Linear layer with LoRA (Low-Rank Adaptation) support.

    Wraps an existing nn.Linear layer and adds trainable low-rank matrices A and B.
    During forward: output = base_linear(x) + (alpha/rank) * (x @ A @ B)

    The base weights are frozen; only A and B are trained.
    """

    def __init__(
        self,
        base_layer: nn.Linear,
        rank: int = 8,
        alpha: float = 16.0,
        dropout: float = 0.0,
    ):
        """
        Initialize LoRA wrapper around a linear layer.

        Args:
            base_layer: The original nn.Linear to wrap
            rank: Rank of the low-rank matrices (smaller = fewer params)
            alpha: Scaling factor (alpha/rank scales the LoRA contribution)
            dropout: Dropout applied to LoRA path
        """
        super().__init__()

        self.base_layer = base_layer
        self.rank = rank
        self.alpha = alpha
        self.scaling = alpha / rank

        in_features = base_layer.in_features
        out_features = base_layer.out_features

        # Freeze base layer
        for param in self.base_layer.parameters():
            param.requires_grad = False

        # LoRA matrices: A projects down, B projects up
        # Initialize A with Kaiming, B with zeros (so LoRA starts as identity)
        self.lora_A = nn.Parameter(torch.zeros(in_features, rank))
        self.lora_B = nn.Parameter(torch.zeros(rank, out_features))
        nn.init.kaiming_uniform_(self.lora_A, a=math.sqrt(5))
        # B starts at zero so initial LoRA contribution is zero

        self.dropout = nn.Dropout(dropout) if dropout > 0 else nn.Identity()

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        # Base forward (frozen)
        base_output = self.base_layer(x)

        # LoRA forward: x @ A @ B, scaled
        lora_output = self.dropout(x) @ self.lora_A @ self.lora_B
        lora_output = lora_output * self.scaling

        return base_output + lora_output

    def merge_weights(self) -> nn.Linear:
        """
        Merge LoRA weights into base layer for inference.

        Returns a new nn.Linear with merged weights (no LoRA overhead).
        """
        merged = nn.Linear(
            self.base_layer.in_features,
            self.base_layer.out_features,
            bias=self.base_layer.bias is not None,
        )

        # Merge: W' = W + (alpha/rank) * A @ B
        with torch.no_grad():
            merged.weight.copy_(
                self.base_layer.weight + self.scaling * (self.lora_A @ self.lora_B).T
            )
            if self.base_layer.bias is not None:
                merged.bias.copy_(self.base_layer.bias)

        return merged


def enable_lora(
    model: nn.Module,
    rank: int = 8,
    alpha: float = 16.0,
    dropout: float = 0.0,
    target_modules: list[str] = None,
) -> int:
    """
    Enable LoRA on a model by wrapping target linear layers.

    Args:
        model: The model to modify
        rank: LoRA rank (default 8)
        alpha: LoRA alpha scaling (default 16)
        dropout: Dropout for LoRA path
        target_modules: List of module name patterns to apply LoRA to.
                       Default: ["qkv_proj", "out_proj"] (attention layers)

    Returns:
        Number of LoRA parameters added
    """
    if target_modules is None:
        target_modules = ["qkv_proj", "out_proj"]

    lora_params = 0

    # Find and replace target modules
    for name, module in list(model.named_modules()):
        for target in target_modules:
            if target in name and isinstance(module, nn.Linear):
                # Get parent module and attribute name
                parent_name = ".".join(name.split(".")[:-1])
                attr_name = name.split(".")[-1]

                if parent_name:
                    parent = model.get_submodule(parent_name)
                else:
                    parent = model

                # Replace with LoRA-wrapped version
                lora_layer = LoRALinear(module, rank=rank, alpha=alpha, dropout=dropout)
                setattr(parent, attr_name, lora_layer)

                # Count new params
                lora_params += lora_layer.lora_A.numel() + lora_layer.lora_B.numel()

    return lora_params


def get_lora_state_dict(model: nn.Module) -> dict:
    """
    Extract only the LoRA parameters from a model.

    Returns a state dict containing only lora_A and lora_B parameters.
    """
    lora_state = {}
    for name, param in model.named_parameters():
        if "lora_A" in name or "lora_B" in name:
            lora_state[name] = param.data.clone()
    return lora_state


def load_lora_state_dict(model: nn.Module, lora_state: dict, strict: bool = True):
    """
    Load LoRA parameters into a model.

    Args:
        model: Model with LoRA layers
        lora_state: State dict from get_lora_state_dict()
        strict: If True, raise error on missing/unexpected keys
    """
    current_state = model.state_dict()
    missing = []
    unexpected = []

    for key, value in lora_state.items():
        if key in current_state:
            current_state[key] = value
        else:
            unexpected.append(key)

    for key in current_state:
        if ("lora_A" in key or "lora_B" in key) and key not in lora_state:
            missing.append(key)

    if strict and (missing or unexpected):
        raise RuntimeError(
            f"LoRA state dict mismatch. Missing: {missing}, Unexpected: {unexpected}"
        )

    model.load_state_dict(current_state, strict=False)


def disable_lora(model: nn.Module, merge: bool = False):
    """
    Disable LoRA on a model.

    Args:
        model: Model with LoRA layers
        merge: If True, merge LoRA weights into base layer before removing.
               If False, just restore original base layers (discard LoRA).
    """
    for name, module in list(model.named_modules()):
        if isinstance(module, LoRALinear):
            parent_name = ".".join(name.split(".")[:-1])
            attr_name = name.split(".")[-1]

            if parent_name:
                parent = model.get_submodule(parent_name)
            else:
                parent = model

            if merge:
                # Merge LoRA into base and replace
                merged = module.merge_weights()
                setattr(parent, attr_name, merged)
            else:
                # Just restore base layer
                setattr(parent, attr_name, module.base_layer)


def count_lora_parameters(model: nn.Module) -> tuple:
    """
    Count trainable and total parameters in a model with LoRA.

    Returns:
        (lora_params, total_params, trainable_params)
    """
    lora_params = 0
    total_params = 0
    trainable_params = 0

    for name, param in model.named_parameters():
        total_params += param.numel()
        if param.requires_grad:
            trainable_params += param.numel()
        if "lora_A" in name or "lora_B" in name:
            lora_params += param.numel()

    return lora_params, total_params, trainable_params
