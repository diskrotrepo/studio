"""
MIDI file validation utilities.

Validates MIDI files by parsing in isolated subprocesses to handle crashes safely.
"""

from pathlib import Path
from tqdm import tqdm
import multiprocessing as mp


# Bad files tracking
BAD_FILES_LOG = Path("bad_midi_files.txt")

# Processing log (helps identify crash-causing files)
PROCESSING_LOG = Path("midi_processing.log")
VALIDATE_TIMEOUT = 30  # seconds per file


def _log_processing(message: str):
    """Log a processing message with immediate flush (survives crashes)."""
    with open(PROCESSING_LOG, "a") as f:
        f.write(f"{message}\n")
        f.flush()


def _validate_single_midi(midi_path_str: str) -> tuple[str, bool, str | None]:
    """
    Validate a single MIDI file by attempting to parse it with symusic.

    Runs in isolated subprocess - if symusic crashes, only this process dies.

    Returns (file_path, is_valid, error_message)
    """
    import signal
    import sys

    _log_processing(f"VALIDATING: {midi_path_str}")

    # Set a 30-second timeout (only works on Unix)
    if sys.platform != 'win32':
        def timeout_handler(signum, frame):
            raise TimeoutError("Validation timed out")
        signal.signal(signal.SIGALRM, timeout_handler)
        signal.alarm(30)

    try:
        from symusic import Score
        # Try to parse the file
        score = Score(midi_path_str)
        # Basic sanity checks
        if not score.tracks:
            _log_processing(f"FAILED: {midi_path_str} (No tracks)")
            if sys.platform != 'win32':
                signal.alarm(0)
            return (midi_path_str, False, "No tracks")
        total_notes = sum(len(t.notes) for t in score.tracks)
        if total_notes == 0:
            _log_processing(f"FAILED: {midi_path_str} (No notes)")
            if sys.platform != 'win32':
                signal.alarm(0)
            return (midi_path_str, False, "No notes")

        # Cancel the alarm on success
        if sys.platform != 'win32':
            signal.alarm(0)

        _log_processing(f"SUCCESS: {midi_path_str}")
        return (midi_path_str, True, None)
    except TimeoutError:
        _log_processing(f"TIMEOUT: {midi_path_str}")
        return (midi_path_str, False, "Timeout after 30s")
    except Exception as e:
        # Cancel the alarm on error
        if sys.platform != 'win32':
            signal.alarm(0)
        _log_processing(f"FAILED: {midi_path_str} ({e})")
        return (midi_path_str, False, str(e))


def validate_midi_files(
    midi_files: list[Path],
    num_workers: int = None,
) -> tuple[list[Path], list[tuple[str, str]]]:
    """
    Validate MIDI files by attempting to parse each one in an isolated subprocess.

    Files that cause crashes (segfaults) or parsing errors are identified and logged.
    Generates a bash script to remove all bad files.

    Args:
        midi_files: List of MIDI file paths to validate
        num_workers: Number of parallel workers (default: half CPU count)

    Returns:
        (valid_files, bad_files) where bad_files is list of (path, error) tuples
    """
    # Clear the processing log for this run
    with open(PROCESSING_LOG, "w") as f:
        f.write(f"=== Validation started: {len(midi_files)} files ===\n")

    if num_workers is None:
        num_workers = max(1, mp.cpu_count() // 2)

    valid_files = []
    bad_files = []

    from concurrent.futures import ProcessPoolExecutor, as_completed, BrokenExecutor

    ctx = mp.get_context('spawn')
    remaining = [str(f) for f in midi_files]

    pbar = tqdm(total=len(remaining), desc="Validating MIDI files")

    # When a bad file crashes a worker, BrokenProcessPool kills ALL remaining
    # futures — not just the bad file. Retry with a fresh pool so innocent
    # files get a fair chance.
    max_retries = 5
    for attempt in range(max_retries):
        if not remaining:
            break

        confirmed_bad = []
        confirmed_good = []
        completed = set()

        try:
            with ProcessPoolExecutor(max_workers=num_workers, mp_context=ctx) as executor:
                futures = {executor.submit(_validate_single_midi, fp): fp
                           for fp in remaining}

                for future in as_completed(futures):
                    file_path = futures[future]
                    try:
                        result_path, is_valid, error = future.result(timeout=VALIDATE_TIMEOUT)
                        completed.add(file_path)
                        if is_valid:
                            confirmed_good.append(Path(result_path))
                        else:
                            confirmed_bad.append((result_path, error or "Unknown error"))
                    except (BrokenExecutor, Exception) as e:
                        if isinstance(e, BrokenExecutor):
                            # Pool is dead — don't mark this file as bad,
                            # it might be an innocent bystander
                            break
                        # Per-future error (e.g. timeout) — this file is bad
                        completed.add(file_path)
                        _log_processing(f"FAILED: {file_path} ({e})")
                        confirmed_bad.append((file_path, str(e)))
                    pbar.update(1)

        except Exception as e:
            print(f"\nPool error: {e}")

        valid_files.extend(confirmed_good)
        bad_files.extend(confirmed_bad)

        # Only retry files we didn't get a definitive answer for
        remaining = [fp for fp in remaining if fp not in completed]
        if remaining:
            # Undo progress bar for files we need to retry
            pbar.total = pbar.n + len(remaining)
            pbar.refresh()
            print(f"\nWorker crashed — retrying {len(remaining)} files (attempt {attempt + 2}/{max_retries})...")

    # Process remaining files one-at-a-time in isolated subprocesses.
    # This way one bad file can only kill its own process.
    if remaining:
        print(f"\nProcessing {len(remaining)} files individually...")
        for fp in remaining:
            try:
                with ProcessPoolExecutor(max_workers=1, mp_context=ctx) as solo:
                    future = solo.submit(_validate_single_midi, fp)
                    result_path, is_valid, error = future.result(timeout=VALIDATE_TIMEOUT)
                    if is_valid:
                        valid_files.append(Path(result_path))
                    else:
                        bad_files.append((result_path, error or "Unknown error"))
            except Exception as e:
                _log_processing(f"FAILED: {fp} (Crash: {e})")
                bad_files.append((fp, f"Crash: {e}"))
            pbar.update(1)

    pbar.close()

    # Save bad files list
    if bad_files:
        _save_bad_files_log(bad_files)

    return valid_files, bad_files


def _save_bad_files_log(bad_files: list[tuple[str, str]]):
    """Save list of bad files with their errors."""
    with open(BAD_FILES_LOG, "w") as f:
        for path, error in bad_files:
            f.write(f"{path}\t{error}\n")
    print(f"Bad files logged to {BAD_FILES_LOG}")
