"""
Music Transformer Model

Model architecture components for single-track and multi-track music generation.
"""

from .lora import (
    LoRALinear,
    enable_lora,
    get_lora_state_dict,
    load_lora_state_dict,
    disable_lora,
    count_lora_parameters,
)
from .sampling import _apply_sampling_filters
from .layers import (
    PositionalEncoding,
    MultiHeadAttention,
    FeedForward,
    TransformerBlock,
)
from .transformer import MusicTransformer
from .multitrack import (
    TrackEmbedding,
    CrossTrackAttention,
    MultiTrackTransformerBlock,
    MultiTrackMusicTransformer,
)

__all__ = [
    "LoRALinear",
    "enable_lora",
    "get_lora_state_dict",
    "load_lora_state_dict",
    "disable_lora",
    "count_lora_parameters",
    "_apply_sampling_filters",
    "PositionalEncoding",
    "MultiHeadAttention",
    "FeedForward",
    "TransformerBlock",
    "MusicTransformer",
    "TrackEmbedding",
    "CrossTrackAttention",
    "MultiTrackTransformerBlock",
    "MultiTrackMusicTransformer",
]
