"""
Generation Pipeline

Model loading, single-track and multi-track music generation, audio export.
"""

from .loader import load_model, load_multitrack_model
from .single_track import generate_music, get_tokens_for_extend
from .multi_track import generate_multitrack_music, add_track_to_midi, replace_track_in_midi, cover_midi
from .instruments import (
    GM_PROGRAM_NAMES, gm_program_name,
    GENRE_TRACK_DEFAULTS, GENRE_INSTRUMENT_POOLS, GENERIC_INSTRUMENT_POOLS,
)
from .audio import midi_to_mp3, find_soundfont
from .cli import main

__all__ = [
    "load_model", "load_multitrack_model",
    "generate_music", "get_tokens_for_extend",
    "generate_multitrack_music", "add_track_to_midi", "replace_track_in_midi", "cover_midi",
    "GM_PROGRAM_NAMES", "gm_program_name",
    "GENRE_TRACK_DEFAULTS", "GENRE_INSTRUMENT_POOLS", "GENERIC_INSTRUMENT_POOLS",
    "midi_to_mp3", "find_soundfont",
    "main",
]
