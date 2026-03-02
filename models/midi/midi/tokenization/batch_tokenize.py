"""
Batch MIDI tokenization with parallel processing and crash recovery.

Handles platform-aware multiprocessing with fallback strategies.
"""

from pathlib import Path
from tqdm import tqdm


class TimeoutError(Exception):
    pass


def _timeout_handler(signum, frame):
    raise TimeoutError("Tokenization timed out")


def _tokenize_single_file(args: tuple) -> tuple[str, list[int] | None, str | None]:
    """
    Worker function to tokenize a single MIDI file in an isolated process.

    Returns (file_path, token_ids or None, error_message or None)
    """
    import signal
    import sys

    midi_path_str, tokenizer_path, min_length, max_length, use_tags, midi_root_str, metadata_path_str = args
    midi_path = Path(midi_path_str)
    midi_root = Path(midi_root_str) if midi_root_str else None
    metadata_path = Path(metadata_path_str) if metadata_path_str else None

    from .validation import _log_processing
    _log_processing(f"TOKENIZING: {midi_path_str}")

    # Set a 30-second timeout for this file (only works on Unix)
    if sys.platform != 'win32':
        signal.signal(signal.SIGALRM, _timeout_handler)
        signal.alarm(30)

    try:
        from symusic import Score
        from .core import get_tokenizer, get_tag_tokens
        from .tag_inference import infer_tags_from_path
        from .midi_io import trim_leading_silence

        # Recreate tokenizer in subprocess (can't pickle REMI objects)
        tokenizer = get_tokenizer(tokenizer_path)
        tag_tokens = get_tag_tokens(tokenizer) if use_tags else {}

        # Load, trim silence/click tracks, then tokenize
        score = Score(str(midi_path))
        score = trim_leading_silence(score)
        tokens = tokenizer(score)

        # tokens is a TokSequence or list of TokSequence (multi-track)
        if hasattr(tokens, 'ids'):
            token_ids = tokens.ids
        elif isinstance(tokens, list) and len(tokens) > 0:
            # Concatenate all tracks to preserve multitrack information
            token_ids = []
            for track_tokens in tokens:
                if hasattr(track_tokens, 'ids'):
                    token_ids.extend(track_tokens.ids)
                else:
                    token_ids.extend(track_tokens)
        else:
            _log_processing(f"FAILED: {midi_path_str} (No tokens extracted)")
            return (midi_path_str, None, "No tokens extracted")

        # Prepend tags if enabled
        if use_tags:
            metadata = None
            if metadata_path:
                from .tag_inference import load_metadata
                metadata = load_metadata(metadata_path)
            tags = infer_tags_from_path(midi_path, midi_root=midi_root, metadata=metadata)
            tag_ids = [tag_tokens[t] for t in tags if t in tag_tokens]
            token_ids = tag_ids + token_ids

        # Filter by length
        if len(token_ids) < min_length:
            _log_processing(f"SKIPPED: {midi_path_str} (Too short: {len(token_ids)} < {min_length})")
            return (midi_path_str, None, f"Too short ({len(token_ids)} < {min_length})")

        # Truncate if too long
        if len(token_ids) > max_length:
            token_ids = token_ids[:max_length]

        # Cancel the alarm on success
        if sys.platform != 'win32':
            signal.alarm(0)

        _log_processing(f"SUCCESS: {midi_path_str} ({len(token_ids)} tokens)")
        return (midi_path_str, token_ids, None)

    except TimeoutError:
        _log_processing(f"TIMEOUT: {midi_path_str}")
        return (midi_path_str, None, "Timeout after 30s")
    except Exception as e:
        # Cancel the alarm on error
        if sys.platform != 'win32':
            signal.alarm(0)
        _log_processing(f"FAILED: {midi_path_str} ({e})")
        return (midi_path_str, None, str(e))


def tokenize_midi_files(
    tokenizer,
    midi_files: list[Path],
    min_length: int = 50,
    max_length: int = 16384,
    use_tags: bool = False,
    tags_dict: dict[str, list[str]] = None,
    num_workers: int = None,
    force_parallel: bool = False,
    midi_root: Path = None,
    metadata_path: Path = None,
) -> list[list[int]]:
    """
    Tokenize a list of MIDI files.

    On macOS/Apple Silicon, uses sequential processing by default because the
    symusic library (C++ native code) is not fork-safe and crashes with multiprocessing.
    On Linux (including with CUDA/A100), uses multiprocessing with spawn context.

    Args:
        tokenizer: The tokenizer to use
        midi_files: List of paths to MIDI files
        min_length: Minimum sequence length to include
        max_length: Maximum sequence length (will truncate)
        use_tags: If True, prepend conditioning tags to sequences
        tags_dict: Optional dict mapping file paths to tag lists.
                   If not provided and use_tags=True, infers from path.
        num_workers: Number of parallel worker processes (auto-detected if None)
        force_parallel: Force parallel processing even on macOS (may crash)
        midi_root: Root directory for MIDI files (used for artist folder detection)
        metadata_path: Path to JSON metadata file for tag lookup

    Returns:
        List of token sequences (as lists of integers)
    """
    import sys
    import platform
    import multiprocessing as mp

    from .validation import PROCESSING_LOG

    # Initialize processing log for this run
    with open(PROCESSING_LOG, "a") as f:
        f.write(f"\n=== Tokenization started: {len(midi_files)} files ===\n")

    is_macos = platform.system() == "Darwin"

    # On macOS, the symusic library crashes with multiprocessing (fork or spawn)
    # because it uses C++ native code that is not fork-safe.
    # Default to sequential processing on macOS unless force_parallel is set.
    if is_macos and not force_parallel:
        print("Using sequential processing (safe for macOS)")
        return _tokenize_sequential(
            tokenizer, midi_files, min_length, max_length, use_tags, tags_dict, midi_root, metadata_path
        )

    # Auto-detect optimal worker count based on platform
    if num_workers is None:
        cpu_count = mp.cpu_count()
        num_workers = min(cpu_count, 8)

    sequences = []
    failed_files = []

    # Save tokenizer temporarily so workers can reload it
    import tempfile
    import os
    temp_dir = tempfile.mkdtemp()
    tokenizer_path = os.path.join(temp_dir, "tokenizer_temp.json")
    tokenizer.save(Path(tokenizer_path))

    # Prepare arguments for each file
    midi_root_str = str(midi_root) if midi_root else None
    metadata_path_str = str(metadata_path) if metadata_path else None
    args_list = [
        (str(f), tokenizer_path, min_length, max_length, use_tags, midi_root_str, metadata_path_str)
        for f in midi_files
    ]

    processed_files = set()

    # Use spawn context on Linux (safer with CUDA in environment)
    # Windows only supports spawn
    ctx_name = "spawn"

    try:
        ctx = mp.get_context(ctx_name)

        with ctx.Pool(processes=num_workers, maxtasksperchild=100) as pool:
            # Use imap_unordered for better memory efficiency
            with tqdm(total=len(midi_files), desc="Tokenizing MIDI files") as pbar:
                for result in pool.imap_unordered(_tokenize_single_file, args_list, chunksize=10):
                    file_path, token_ids, error = result
                    processed_files.add(file_path)
                    if token_ids is not None:
                        sequences.append(token_ids)
                    elif error:
                        failed_files.append((file_path, error))
                    pbar.update(1)

    except Exception as e:
        print(f"\nMultiprocessing error: {e}")
        # Keep sequences collected so far, try to process remaining files sequentially
        remaining_files = [f for f in midi_files if str(f) not in processed_files]
        if remaining_files:
            print(f"Keeping {len(sequences)} sequences, processing {len(remaining_files)} remaining files sequentially...")
            try:
                additional = _tokenize_sequential(
                    tokenizer, remaining_files, min_length, max_length, use_tags, tags_dict, midi_root, metadata_path
                )
                sequences.extend(additional)
            except Exception as seq_err:
                print(f"Sequential fallback also failed: {seq_err}")
                print(f"Continuing with {len(sequences)} sequences collected so far...")
        else:
            print(f"All files were processed. Continuing with {len(sequences)} sequences...")
    finally:
        # Clean up temp tokenizer
        import shutil
        shutil.rmtree(temp_dir, ignore_errors=True)

    if failed_files:
        log_path = Path("tokenization_failures.log")
        with open(log_path, "w") as f:
            for path, err in failed_files:
                f.write(f"{path}\t{err}\n")
        print(f"\nFailed to tokenize {len(failed_files)} files (see {log_path})")

    return sequences


def _tokenize_sequential(
    tokenizer,
    midi_files: list[Path],
    min_length: int,
    max_length: int,
    use_tags: bool,
    tags_dict: dict[str, list[str]] | None,
    midi_root: Path = None,
    metadata_path: Path = None,
) -> list[list[int]]:
    """
    Parallel tokenization with crash recovery.

    Uses a single pool for speed, with fallback to individual processing
    if the pool crashes.
    """
    import tempfile
    import os
    import multiprocessing as mp

    sequences = []
    failed_files = []

    # Save tokenizer temporarily so workers can reload it
    temp_dir = tempfile.mkdtemp()
    tokenizer_path = os.path.join(temp_dir, "tokenizer_temp.json")
    tokenizer.save(Path(tokenizer_path))

    # Use half the CPU cores
    num_workers = max(1, mp.cpu_count() // 2)

    # Convert to list of args
    midi_root_str = str(midi_root) if midi_root else None
    metadata_path_str = str(metadata_path) if metadata_path else None
    all_args = [(str(f), tokenizer_path, min_length, max_length, use_tags, midi_root_str, metadata_path_str) for f in midi_files]

    pbar = tqdm(total=len(midi_files), desc="Tokenizing MIDI files")
    processed_paths = set()

    try:
        ctx = mp.get_context('spawn')
        # Use larger maxtasksperchild and chunksize for speed
        with ctx.Pool(processes=num_workers, maxtasksperchild=50) as pool:
            chunksize = max(1, len(all_args) // (num_workers * 10))
            for result in pool.imap_unordered(_tokenize_single_file, all_args, chunksize=chunksize):
                file_path, token_ids, error = result
                processed_paths.add(file_path)
                if token_ids is not None:
                    sequences.append(token_ids)
                elif error:
                    failed_files.append((file_path, error))
                pbar.update(1)

    except Exception as e:
        # Pool crashed - process remaining files individually
        remaining = [args for args in all_args if args[0] not in processed_paths]
        if remaining:
            print(f"\nPool crashed, processing {len(remaining)} remaining files individually...")
            ctx = mp.get_context('spawn')
            for args in remaining:
                file_path = args[0]
                try:
                    with ctx.Pool(processes=1, maxtasksperchild=1) as single_pool:
                        result = single_pool.apply(_tokenize_single_file, (args,))
                        file_path, token_ids, error = result
                        if token_ids is not None:
                            sequences.append(token_ids)
                        elif error:
                            failed_files.append((file_path, error))
                except Exception:
                    failed_files.append((file_path, "CRASH: Segmentation fault"))
                pbar.update(1)

    finally:
        pbar.close()
        import shutil
        shutil.rmtree(temp_dir, ignore_errors=True)

    # Log failures silently to file
    if failed_files:
        log_path = Path("tokenization_failures.log")
        with open(log_path, "w") as f:
            for path, err in failed_files:
                f.write(f"{path}\t{err}\n")
        print(f"Skipped {len(failed_files)} files (see {log_path})")

    return sequences
