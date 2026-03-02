"""Token cache loading."""

import pickle
from pathlib import Path

# Cache format version - increment when changing cache structure
CACHE_VERSION = 1


def load_token_cache(
    cache_path: Path, num_midi_files: int = None, logger=None
) -> tuple[list, bool] | None:
    """Load tokenized sequences from cache if valid.

    Args:
        cache_path: Path to the cache file
        num_midi_files: Number of MIDI files found in directory (for warning only)
        logger: Optional logger instance

    Returns:
        tuple of (sequences, is_multitrack) if valid cache found, None otherwise
    """
    log = logger.info if logger else print
    log_warn = logger.warning if logger else print

    if not cache_path.exists():
        return None
    try:
        with open(cache_path, "rb") as f:
            data = pickle.load(f)

        # Validate cache structure
        if not isinstance(data, dict):
            log_warn("Cache has invalid format (expected dict)")
            return None

        if "sequences" not in data:
            log_warn("Cache missing required 'sequences' key")
            return None

        # Check cache version (optional field for backwards compatibility)
        cache_version = data.get("version", 0)
        if cache_version > CACHE_VERSION:
            log_warn(
                f"Cache version {cache_version} is newer than supported version {CACHE_VERSION}. "
                "Please update your code or regenerate the cache."
            )
            return None

        is_multitrack = data.get("multitrack", False)
        sequences = data["sequences"]
        cached_file_count = data.get("file_count", len(sequences))

        # Warn if file count differs (user may have added/removed files)
        if num_midi_files is not None and num_midi_files != cached_file_count:
            log_warn(
                f"Found {num_midi_files} MIDI files but cache has {cached_file_count} tokenized files"
            )
            log(
                "      (This is normal if some files were invalid during pre-tokenization)"
            )
            log("      Run 'python pretokenize.py' again if you've added new files")

        return sequences, is_multitrack
    except Exception as e:
        log_warn(f"Cache load failed: {e}")
        return None
