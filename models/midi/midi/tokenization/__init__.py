"""
MIDI Tokenization Pipeline

Tokenizer, tags, validation, batch processing, and MIDI I/O.
"""

from .core import (
    MULTITRACK_TOKENS,
    TRACK_TYPE_TOKENS,
    MAX_TRACKS,
    get_tokenizer,
    save_tokenizer,
    get_tag_tokens,
    parse_tags,
)
from .tags import (
    GENRE_TAGS,
    MOOD_TAGS,
    TEMPO_TAGS,
    KEY_TAGS,
    TIMESIG_TAGS,
    DENSITY_TAGS,
    DYNAMICS_TAGS,
    LENGTH_TAGS,
    REGISTER_TAGS,
    ARRANGEMENT_TAGS,
    RHYTHM_TAGS,
    HARMONY_TAGS,
    ARTICULATION_TAGS,
    EXPRESSION_TAGS,
    ERA_TAGS,
    ARTIST_TAGS,
    DISCOVERED_GENRES,
    ALL_TAGS,
    discover_genres,
    discover_artists,
    get_all_tags,
    get_available_tags,
)
from .tag_inference import (
    infer_tempo_from_midi,
    extract_midi_attributes,
    infer_tags_from_path,
    load_metadata,
    infer_tags_from_metadata,
)
from .lastfm_tags import (
    LASTFM_GENRE_MAP,
    LASTFM_MOOD_MAP,
    map_lastfm_tags,
)
from .validation import (
    _log_processing,
    _validate_single_midi,
    validate_midi_files,
    _save_bad_files_log,
    PROCESSING_LOG,
    BAD_FILES_LOG,
    VALIDATE_TIMEOUT,
)
from .batch_tokenize import (
    TimeoutError,
    _timeout_handler,
    _tokenize_single_file,
    tokenize_midi_files,
    _tokenize_sequential,
)
from .midi_io import (
    humanize_midi,
    tokens_to_midi,
    tokenize_multitrack_midi,
    tokens_to_multitrack_midi,
)
