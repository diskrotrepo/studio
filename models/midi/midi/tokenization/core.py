"""
MIDI Tokenizer Core

Core tokenizer functions: create, save, load, and parse tags.
"""

import warnings
from pathlib import Path

from miditok import REMI, TokenizerConfig

# Suppress miditok warnings
warnings.filterwarnings("ignore", message="Attribute controls are not compatible")
warnings.filterwarnings("ignore", message=".*special token .* must contain one underscore")

from . import tags as _tags
from .tags import get_all_tags, discover_artists, discover_genres
from .tag_inference import load_metadata

# ============================================================================
# Tokenizer core constants
# ============================================================================

# Multi-track special tokens
MULTITRACK_TOKENS = [
    "TRACK_START",   # Beginning of a track
    "TRACK_END",     # End of a track
    "BAR_START",     # Explicit bar marker for timing synchronization
]

# Track type tokens for role-based conditioning
TRACK_TYPE_TOKENS = [
    "TRACKTYPE_MELODY",
    "TRACKTYPE_BASS",
    "TRACKTYPE_CHORDS",
    "TRACKTYPE_DRUMS",
    "TRACKTYPE_PERCUSSION",
    "TRACKTYPE_PAD",
    "TRACKTYPE_STRINGS",
    "TRACKTYPE_LEAD",
    "TRACKTYPE_ORGAN",
    "TRACKTYPE_BRASS",
    "TRACKTYPE_WOODWIND",
    "TRACKTYPE_SYNTH",
    "TRACKTYPE_CHOIR",
    "TRACKTYPE_FX",
    "TRACKTYPE_OTHER",
]

# Maximum number of tracks supported
MAX_TRACKS = 16


# ============================================================================
# Tokenizer core functions
# ============================================================================

def get_tokenizer(tokenizer_path: str = None, midi_dir: str | Path = None, metadata_path: str | Path = None) -> REMI:
    """
    Get or create a MIDI tokenizer.

    We use REMI (REvamped MIDI-derived events) encoding, which represents
    music as a sequence of:
    - Pitch tokens (note values)
    - Velocity tokens (how hard the note is played)
    - Duration tokens (how long the note lasts)
    - Time-shift tokens (time between events)
    - Special tokens (bar lines, etc.)

    Args:
        tokenizer_path: Path to load existing tokenizer from
        midi_dir: Path to MIDI directory for discovering artist/genre folders
        metadata_path: Path to JSON metadata file (preferred over folder discovery)

    Returns:
        Configured tokenizer instance
    """
    if tokenizer_path and Path(tokenizer_path).exists():
        return REMI(params=Path(tokenizer_path))

    # If metadata provided, load artists from JSON instead of folder scanning
    if metadata_path and not _tags.ARTIST_TAGS:
        metadata = load_metadata(Path(metadata_path))
        artists = set()
        for entry in metadata.values():
            artist = entry.get("artist", "")
            if artist:
                clean = artist.lower().replace(' ', '_').replace('-', '_')
                artists.add(clean)
        if artists:
            _tags.ARTIST_TAGS = sorted(artists)
            print(f"Loaded {len(_tags.ARTIST_TAGS)} artists from metadata")
    elif midi_dir and not _tags.ARTIST_TAGS:
        _tags.ARTIST_TAGS = discover_artists(midi_dir)
        if _tags.ARTIST_TAGS:
            print(f"Discovered {len(_tags.ARTIST_TAGS)} artists: {', '.join(_tags.ARTIST_TAGS[:10])}{'...' if len(_tags.ARTIST_TAGS) > 10 else ''}")

    # Discover genres from folder structure (only if no metadata)
    if not metadata_path and midi_dir and not _tags.DISCOVERED_GENRES:
        _tags.DISCOVERED_GENRES = discover_genres(midi_dir)
        if _tags.DISCOVERED_GENRES:
            print(f"Discovered {len(_tags.DISCOVERED_GENRES)} genres: {', '.join(_tags.DISCOVERED_GENRES[:10])}{'...' if len(_tags.DISCOVERED_GENRES) > 10 else ''}")

    # Get all tags including discovered artists
    all_tags = get_all_tags(include_artists=True)

    # Configure tokenizer
    config = TokenizerConfig(
        # Pitch range (MIDI note numbers, 21=A0, 108=C8 for piano)
        pitch_range=(21, 109),

        # Beat resolution (ticks per beat for time quantization)
        beat_res={(0, 4): 8, (4, 12): 4},  # Higher resolution for first 4 beats

        # Number of velocity bins (dynamics)
        num_velocities=32,

        # Use special tokens (including conditioning tags and multi-track tokens)
        special_tokens=["PAD", "BOS", "EOS"] + all_tags + MULTITRACK_TOKENS + TRACK_TYPE_TOKENS,

        # Use programs (instruments) - enables multitrack with different instruments
        use_programs=True,

        # Disable attribute controls (incompatible with one_token_stream_for_programs)
        use_attribute_controls=False,

        # Use time signatures
        use_time_signatures=True,

        # Use tempo
        use_tempos=True,
        num_tempos=32,  # Number of tempo bins
        tempo_range=(40, 250),
    )

    tokenizer = REMI(config)
    return tokenizer


def save_tokenizer(tokenizer: REMI, path: str):
    """Save tokenizer for later use."""
    tokenizer.save(Path(path))
    print(f"Tokenizer saved to {path}")


def get_tag_tokens(tokenizer: REMI) -> dict[str, int]:
    """Get mapping of tag names to token IDs (including artist tags)."""
    tag_tokens = {}
    all_tags = get_all_tags(include_artists=True)
    for tag in all_tags:
        # Check both formats: "TAG" and "TAG_None"
        if tag in tokenizer.vocab:
            tag_tokens[tag] = tokenizer.vocab[tag]
        elif f"{tag}_None" in tokenizer.vocab:
            tag_tokens[tag] = tokenizer.vocab[f"{tag}_None"]
    return tag_tokens


def parse_tags(tag_string: str, tokenizer: REMI) -> list[int]:
    """
    Parse user-friendly tag string into token IDs.

    Supports formats:
    - "jazz happy fast" - matches genre/mood/tempo
    - "artist:my_artist" - explicit artist tag
    - "beethoven jazz" - artist name or genre (matched in order)

    Args:
        tag_string: Space-separated tags like "jazz happy" or "artist:my_artist jazz"
        tokenizer: The tokenizer instance

    Returns:
        List of tag token IDs
    """
    tag_tokens = get_tag_tokens(tokenizer)
    token_ids = []

    for tag in tag_string.lower().split():
        # Handle explicit "artist:name" syntax
        if tag.startswith("artist:"):
            artist_name = tag[7:].replace('-', '_').replace(' ', '_')
            artist_tag = f"ARTIST_{artist_name.upper()}"
            if artist_tag in tag_tokens:
                token_ids.append(tag_tokens[artist_tag])
            continue

        # Try to match against known tags
        matched = False
        for tag_name, token_id in tag_tokens.items():
            # Match "jazz" to "GENRE_JAZZ", "happy" to "MOOD_HAPPY", etc.
            if tag.upper() in tag_name:
                token_ids.append(token_id)
                matched = True
                break

        # If no match, try as artist name directly
        if not matched:
            artist_tag = f"ARTIST_{tag.upper().replace('-', '_')}"
            if artist_tag in tag_tokens:
                token_ids.append(tag_tokens[artist_tag])

    return token_ids
