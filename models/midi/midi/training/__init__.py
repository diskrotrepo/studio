"""
Training Pipeline

Configuration, datasets, training loop, and checkpoint management.
"""

from .config import TrainingConfig
from .cache import CACHE_VERSION, load_token_cache
from .cli import main

__all__ = ["TrainingConfig", "CACHE_VERSION", "load_token_cache", "main"]
