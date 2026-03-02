"""
MIDI Music Generation Package

Core components for training and generating MIDI music with transformers.
"""

from .model import MusicTransformer, MultiTrackMusicTransformer
from .tokenizer import get_tokenizer, get_available_tags


def __getattr__(name: str):
    """Lazy-import generate symbols to avoid circular import when running
    ``python -m midi.generate``."""
    if name in ("generate_music", "generate_multitrack_music", "load_model"):
        from . import generation as _gen
        return getattr(_gen, name)
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")


__all__ = [
    "MusicTransformer",
    "MultiTrackMusicTransformer",
    "get_tokenizer",
    "get_available_tags",
    "generate_music",
    "generate_multitrack_music",
    "load_model",
]
