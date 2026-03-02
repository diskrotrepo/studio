"""
Conditioning tag system for MIDI music generation.

Defines all tag constants (genre, mood, tempo, etc.) and discovery functions
for auto-detecting tags from folder structures.
"""

from pathlib import Path


# Available conditioning tags
# Extended genre list to match organize_by_genre.py categories
GENRE_TAGS = [
    "rock", "metal", "pop", "electronic", "hip_hop", "r&b_soul",
    "jazz", "classical", "country", "blues", "reggae", "latin",
    "world", "soundtrack", "easy_listening", "ambient", "folk", "unknown"
]
MOOD_TAGS = ["happy", "sad", "energetic", "calm", "dark", "uplifting", "melancholic", "intense"]
TEMPO_TAGS = ["slow", "medium", "fast"]

# Phase 1: Core musical attributes (extracted from MIDI content)
KEY_TAGS = ["major", "minor"]
TIMESIG_TAGS = ["4_4", "3_4", "6_8", "2_4", "5_4", "7_8", "12_8", "other_time"]
DENSITY_TAGS = ["sparse", "moderate", "dense"]
DYNAMICS_TAGS = ["soft", "moderate_dynamics", "loud", "dynamic"]
LENGTH_TAGS = ["short", "medium_length", "long"]

# Phase 2: Structural attributes
REGISTER_TAGS = ["low_register", "mid_register", "high_register", "wide_range"]
ARRANGEMENT_TAGS = ["solo", "duo", "small_ensemble", "full_arrangement"]
RHYTHM_TAGS = ["straight", "swing", "syncopated", "complex_rhythm"]
HARMONY_TAGS = ["simple_harmony", "moderate_harmony", "complex_harmony"]

# Phase 3: Expressive attributes
ARTICULATION_TAGS = ["legato", "staccato", "mixed_articulation"]
EXPRESSION_TAGS = ["mechanical", "expressive", "highly_expressive"]
ERA_TAGS = ["vintage", "modern", "contemporary"]

# Artist and genre tags - populated dynamically from folder structure
ARTIST_TAGS: list[str] = []
DISCOVERED_GENRES: list[str] = []


def discover_genres(midi_dir: str | Path = "midi_files") -> list[str]:
    """
    Discover genre names from folder structure.

    Expects genre-organized structure:
        midi_files/
        ├── Rock/
        │   └── artist/
        │       └── song.mid
        ├── Jazz/
        │   └── artist/
        │       └── song.mid

    Returns sorted list of lowercase genre folder names.
    """
    midi_path = Path(midi_dir)
    if not midi_path.exists():
        return []

    genres = []
    for item in midi_path.iterdir():
        if item.is_dir() and not item.name.startswith('.'):
            # Check if this folder contains artist subfolders (genre structure)
            subfolders = [d for d in item.iterdir() if d.is_dir() and not d.name.startswith('.')]
            has_nested_midi = any(
                list(sf.rglob("*.mid")) + list(sf.rglob("*.midi"))
                for sf in subfolders
            )
            if subfolders and has_nested_midi:
                # This is a genre folder
                genre_name = item.name.lower().replace(' ', '_').replace('-', '_')
                genres.append(genre_name)

    return sorted(set(genres))


def discover_artists(midi_dir: str | Path = "midi_files") -> list[str]:
    """
    Discover artist names from folder structure.

    Supports two folder structures:
        1. Flat: midi_files/<artist>/<song>.mid
        2. Genre-organized: midi_files/<genre>/<artist>/<song>.mid

    Returns sorted list of lowercase artist folder names.
    """
    midi_path = Path(midi_dir)
    if not midi_path.exists():
        return []

    artists = []
    for item in midi_path.iterdir():
        if item.is_dir() and not item.name.startswith('.'):
            # Check if this is a genre folder (contains artist subfolders)
            # or an artist folder (contains MIDI files directly)
            direct_midi = list(item.glob("*.mid")) + list(item.glob("*.midi"))
            subfolders = [d for d in item.iterdir() if d.is_dir() and not d.name.startswith('.')]

            if direct_midi:
                # This is an artist folder with MIDI files directly inside
                artist_name = item.name.lower().replace(' ', '_').replace('-', '_')
                artists.append(artist_name)
            elif subfolders:
                # This might be a genre folder - check subfolders for artists
                for subfolder in subfolders:
                    midi_files = list(subfolder.rglob("*.mid")) + list(subfolder.rglob("*.midi"))
                    if midi_files:
                        artist_name = subfolder.name.lower().replace(' ', '_').replace('-', '_')
                        artists.append(artist_name)

    return sorted(set(artists))


def get_all_tags(include_artists: bool = True, include_discovered_genres: bool = True) -> list[str]:
    """Get all conditioning tags, optionally including discovered artists and genres."""
    # Start with base genre tags
    genre_set = set(g.upper() for g in GENRE_TAGS)

    # Add discovered genres from folder structure
    if include_discovered_genres and DISCOVERED_GENRES:
        genre_set.update(g.upper() for g in DISCOVERED_GENRES)

    tags = (
        # Original tags
        [f"GENRE_{g}" for g in sorted(genre_set)] +
        [f"MOOD_{m.upper()}" for m in MOOD_TAGS] +
        [f"TEMPO_{t.upper()}" for t in TEMPO_TAGS] +
        # Phase 1: Core musical attributes
        [f"KEY_{k.upper()}" for k in KEY_TAGS] +
        [f"TIMESIG_{t.upper()}" for t in TIMESIG_TAGS] +
        [f"DENSITY_{d.upper()}" for d in DENSITY_TAGS] +
        [f"DYNAMICS_{d.upper()}" for d in DYNAMICS_TAGS] +
        [f"LENGTH_{l.upper()}" for l in LENGTH_TAGS] +
        # Phase 2: Structural attributes
        [f"REGISTER_{r.upper()}" for r in REGISTER_TAGS] +
        [f"ARRANGEMENT_{a.upper()}" for a in ARRANGEMENT_TAGS] +
        [f"RHYTHM_{r.upper()}" for r in RHYTHM_TAGS] +
        [f"HARMONY_{h.upper()}" for h in HARMONY_TAGS] +
        # Phase 3: Expressive attributes
        [f"ARTICULATION_{a.upper()}" for a in ARTICULATION_TAGS] +
        [f"EXPRESSION_{e.upper()}" for e in EXPRESSION_TAGS] +
        [f"ERA_{e.upper()}" for e in ERA_TAGS]
    )
    if include_artists and ARTIST_TAGS:
        tags += [f"ARTIST_{a.upper()}" for a in ARTIST_TAGS]
    return tags


# Static tags (without artists) for backwards compatibility
ALL_TAGS = (
    [f"GENRE_{g.upper()}" for g in GENRE_TAGS] +
    [f"MOOD_{m.upper()}" for m in MOOD_TAGS] +
    [f"TEMPO_{t.upper()}" for t in TEMPO_TAGS] +
    [f"KEY_{k.upper()}" for k in KEY_TAGS] +
    [f"TIMESIG_{t.upper()}" for t in TIMESIG_TAGS] +
    [f"DENSITY_{d.upper()}" for d in DENSITY_TAGS] +
    [f"DYNAMICS_{d.upper()}" for d in DYNAMICS_TAGS] +
    [f"LENGTH_{l.upper()}" for l in LENGTH_TAGS] +
    [f"REGISTER_{r.upper()}" for r in REGISTER_TAGS] +
    [f"ARRANGEMENT_{a.upper()}" for a in ARRANGEMENT_TAGS] +
    [f"RHYTHM_{r.upper()}" for r in RHYTHM_TAGS] +
    [f"HARMONY_{h.upper()}" for h in HARMONY_TAGS] +
    [f"ARTICULATION_{a.upper()}" for a in ARTICULATION_TAGS] +
    [f"EXPRESSION_{e.upper()}" for e in EXPRESSION_TAGS] +
    [f"ERA_{e.upper()}" for e in ERA_TAGS]
)


def get_available_tags(tokenizer=None) -> dict[str, list[str]]:
    """Return available tags grouped by category.

    If a tokenizer is provided, scans its vocab for all tag tokens
    (including artists and discovered genres baked in during training).
    """
    result = {
        "genre": list(GENRE_TAGS),
        "mood": list(MOOD_TAGS),
        "tempo": list(TEMPO_TAGS),
    }
    if ARTIST_TAGS:
        result["artist"] = list(ARTIST_TAGS)

    if tokenizer is not None:
        # Scan vocab for tag tokens not in the hardcoded lists
        prefixes = {
            "genre": "GENRE_", "mood": "MOOD_", "tempo": "TEMPO_",
            "artist": "ARTIST_", "key": "KEY_", "timesig": "TIMESIG_",
            "density": "DENSITY_", "dynamics": "DYNAMICS_", "length": "LENGTH_",
            "register": "REGISTER_", "arrangement": "ARRANGEMENT_",
            "rhythm": "RHYTHM_", "harmony": "HARMONY_",
            "articulation": "ARTICULATION_", "expression": "EXPRESSION_",
            "era": "ERA_",
        }
        for token_name in tokenizer.vocab:
            for category, prefix in prefixes.items():
                if token_name.startswith(prefix):
                    # Strip prefix, lowercase, drop _None suffix
                    tag = token_name[len(prefix):].lower().removesuffix("_none")
                    if not tag:
                        continue
                    if category not in result:
                        result[category] = []
                    if tag not in result[category]:
                        result[category].append(tag)
                    break
        # Sort each category
        for category in result:
            result[category].sort()

    return result
