"""
MIDI I/O and humanization utilities.

Handles conversion between token sequences and MIDI files,
and adds human-like performance variations.
"""

import random
from pathlib import Path

from symusic import Score

# GM percussion pitches commonly used for click/metronome tracks
_CLICK_PITCHES = {33, 34, 37, 75, 76, 77}


def _is_click_track(track) -> bool:
    """Detect if a track is a click/metronome track."""
    name = getattr(track, 'name', '') or ''
    if any(kw in name.lower() for kw in ("click", "metronome", "count")):
        return True

    # Drum track using only known click/metronome sounds
    if getattr(track, 'is_drum', False) and track.notes:
        distinct_pitches = {n.pitch for n in track.notes}
        if distinct_pitches.issubset(_CLICK_PITCHES):
            return True

    return False


def trim_leading_silence(score: Score) -> Score:
    """
    Remove click tracks and leading silent bars from a MIDI Score.

    Detects and removes click/metronome tracks, then shifts all remaining
    events forward to eliminate leading silence. Only trims whole bars
    to preserve bar-relative timing.

    Args:
        score: symusic Score object

    Returns:
        The modified Score
    """
    # Remove click tracks
    for i in range(len(score.tracks) - 1, -1, -1):
        if _is_click_track(score.tracks[i]):
            del score.tracks[i]

    if not score.tracks:
        return score

    # Find earliest note onset across all remaining tracks
    earliest = None
    for track in score.tracks:
        for note in track.notes:
            if earliest is None or note.time < earliest:
                earliest = note.time

    if earliest is None or earliest == 0:
        return score

    tpq = score.ticks_per_quarter if hasattr(score, 'ticks_per_quarter') else 480

    # Compute bar length from first time signature (default 4/4)
    ticks_per_bar = tpq * 4
    if hasattr(score, 'time_signatures') and score.time_signatures:
        ts = score.time_signatures[0]
        ticks_per_bar = tpq * 4 * ts.numerator // ts.denominator

    # Only shift by whole bars to preserve bar-relative position
    shift = (earliest // ticks_per_bar) * ticks_per_bar

    if shift < ticks_per_bar:
        return score  # less than 1 full bar of silence

    # Shift all track events
    for track in score.tracks:
        for note in track.notes:
            note.time = max(0, note.time - shift)
        if hasattr(track, 'controls'):
            for ctrl in track.controls:
                ctrl.time = max(0, ctrl.time - shift)
        if hasattr(track, 'pitch_bends'):
            for pb in track.pitch_bends:
                pb.time = max(0, pb.time - shift)
        if hasattr(track, 'pedals'):
            for pedal in track.pedals:
                pedal.time = max(0, pedal.time - shift)

    # Shift global events
    if hasattr(score, 'tempos'):
        for tempo in score.tempos:
            tempo.time = max(0, tempo.time - shift)
    if hasattr(score, 'time_signatures'):
        for ts in score.time_signatures:
            ts.time = max(0, ts.time - shift)
    if hasattr(score, 'key_signatures'):
        for ks in score.key_signatures:
            ks.time = max(0, ks.time - shift)
    if hasattr(score, 'markers'):
        for marker in score.markers:
            marker.time = max(0, marker.time - shift)
    if hasattr(score, 'lyrics'):
        for lyric in score.lyrics:
            lyric.time = max(0, lyric.time - shift)

    return score


def humanize_midi(
    midi: Score,
    timing_jitter_ms: int = 5,
    velocity_jitter: int = 2,
    duration_variance: float = 0.0,
    beat_accent: int = 0,
    legato_overlap: float = 1.0,
    phrase_dynamics: float = 0.0,
    swing_amount: float = 0.0,
) -> Score:
    """
    Add human feel to generated MIDI by introducing subtle variations.

    Args:
        midi: symusic Score object to humanize
        timing_jitter_ms: Maximum timing offset in milliseconds (default +/-20ms)
        velocity_jitter: Maximum velocity variation (default +/-4 levels)
        duration_variance: Maximum duration variation as fraction (default +/-5%)
        beat_accent: Velocity boost for downbeats (default +8)
        legato_overlap: Duration multiplier for note overlap (default 1.05 = 5% longer)
        phrase_dynamics: Amplitude of 4-bar phrase velocity swell (default 0.12 = +/-12%)
        swing_amount: Swing feel for off-beat 8ths (0.0=straight, 0.1=light, 0.2=heavy)

    Returns:
        The humanized Score object (modified in place)
    """
    import math

    ticks_per_beat = midi.ticks_per_quarter if hasattr(midi, 'ticks_per_quarter') else 480
    ticks_per_bar = ticks_per_beat * 4
    eighth_note = ticks_per_beat // 2

    # Get actual BPM from MIDI (default to 120 if not specified)
    bpm = 120.0
    if hasattr(midi, 'tempos') and midi.tempos:
        bpm = midi.tempos[0].qpm

    # Convert ms to ticks using actual tempo
    ms_per_beat = 60000.0 / bpm  # e.g., 500ms at 120 BPM, 400ms at 150 BPM
    ticks_per_ms = ticks_per_beat / ms_per_beat
    timing_jitter_ticks = int(timing_jitter_ms * ticks_per_ms)

    for track in midi.tracks:
        for note in track.notes:
            # 1. Beat accents - emphasize downbeats (beats 1 and 3)
            if beat_accent > 0:
                beat_in_bar = (note.time % ticks_per_bar) // ticks_per_beat
                if beat_in_bar in [0, 2]:  # beats 1 and 3
                    note.velocity = min(127, note.velocity + beat_accent)

            # 2. Phrase dynamics - velocity swell over 4-bar phrases
            if phrase_dynamics > 0:
                phrase_length = ticks_per_bar * 4
                phrase_position = (note.time % phrase_length) / phrase_length
                # Arc shape: rises to peak at 60%, then fades
                swell = 1.0 + phrase_dynamics * math.sin(phrase_position * math.pi)
                note.velocity = max(1, min(127, int(note.velocity * swell)))

            # 3. Swing - delay off-beat 8th notes
            if swing_amount > 0:
                position_in_beat = note.time % ticks_per_beat
                # Check if this is an off-beat 8th note
                if abs(position_in_beat - eighth_note) < ticks_per_beat // 8:
                    swing_delay = int(ticks_per_beat * swing_amount)
                    note.time += swing_delay

            # 4. Micro-timing jitter
            if timing_jitter_ticks > 0:
                offset = random.randint(-timing_jitter_ticks, timing_jitter_ticks)
                note.time = max(0, note.time + offset)

            # 5. Velocity variation
            if velocity_jitter > 0:
                vel_offset = random.randint(-velocity_jitter, velocity_jitter)
                note.velocity = max(1, min(127, note.velocity + vel_offset))

            # 6. Legato overlap - extend notes slightly
            if legato_overlap > 1.0:
                note.duration = max(1, int(note.duration * legato_overlap))

            # 7. Duration variation
            if duration_variance > 0:
                variance = 1.0 + random.uniform(-duration_variance, duration_variance)
                note.duration = max(1, int(note.duration * variance))

    return midi


def tokens_to_midi(tokenizer, tokens: list[int], output_path: str):
    """
    Convert token sequence back to MIDI file.

    Args:
        tokenizer: The tokenizer
        tokens: List of token IDs
        output_path: Where to save the MIDI file
    """
    from .core import get_tag_tokens

    # Get tag token IDs to filter them out (miditok can't decode them)
    tag_token_ids = set(get_tag_tokens(tokenizer).values())

    # Filter out invalid token IDs and tag tokens
    vocab_size = len(tokenizer)
    valid_tokens = [
        t for t in tokens
        if 0 <= t < vocab_size and t not in tag_token_ids
    ]

    if len(valid_tokens) < len(tokens):
        print(f"Note: Filtered out {len(tokens) - len(valid_tokens)} non-music tokens")

    if not valid_tokens:
        raise ValueError("No valid tokens to decode after filtering")

    # Pass flat list for miditok's expected format
    midi = tokenizer.decode(valid_tokens)
    midi = humanize_midi(midi)
    midi.dump_midi(output_path)
    print(f"MIDI saved to {output_path}")


def _build_from_per_track(
    per_track_ids: list[list[int]],
    score: Score,
    prefix_tokens: list[int],
    tokenizer,
    track_start_id: int | None,
    track_end_id: int | None,
    bar_start_id: int | None,
    max_tracks: int,
) -> tuple[list[int], list[dict]]:
    """Build multitrack token sequence when the tokenizer already returns per-track lists."""
    from ..model.multitrack_utils import infer_track_type

    all_tokens = list(prefix_tokens)
    track_infos = []

    id_to_token = {tid: name for name, tid in tokenizer.vocab.items()}

    for track_idx, track_token_ids in enumerate(per_track_ids[:max_tracks]):
        track_start_pos = len(all_tokens)
        bar_positions = []

        if track_start_id is not None:
            all_tokens.append(track_start_id)

        # Get program from the score track if available
        program = 0
        if track_idx < len(score.tracks):
            tr = score.tracks[track_idx]
            program = tr.program if hasattr(tr, 'program') else 0

        program_token = f"Program_{program}"
        if program_token in tokenizer.vocab:
            all_tokens.append(tokenizer.vocab[program_token])

        track_type = "other"
        if track_idx < len(score.tracks):
            track_type = infer_track_type(score.tracks[track_idx], program)

        track_type_token = f"TRACKTYPE_{track_type.upper()}"
        if track_type_token in tokenizer.vocab:
            all_tokens.append(tokenizer.vocab[track_type_token])

        for token_id in track_token_ids:
            token_name = id_to_token.get(token_id, "")
            if token_name.startswith("Bar_") or token_name == "Bar":
                if bar_start_id is not None:
                    bar_positions.append(len(all_tokens))
                    all_tokens.append(bar_start_id)
            all_tokens.append(token_id)

        if track_end_id is not None:
            all_tokens.append(track_end_id)

        track_infos.append({
            'track_idx': track_idx,
            'instrument': program,
            'track_type': track_type,
            'start_token_pos': track_start_pos,
            'end_token_pos': len(all_tokens),
            'bar_positions': bar_positions,
        })

    # EOS
    eos_id = tokenizer.vocab.get("EOS_None", tokenizer.vocab.get("EOS"))
    if eos_id is not None:
        all_tokens.append(eos_id)

    return all_tokens, track_infos


def tokenize_multitrack_midi(
    tokenizer,
    midi_path: Path,
    max_tracks: int = 16,
    use_tags: bool = True,
    midi_root: Path = None,
    metadata: dict = None,
) -> tuple[list[int], list[dict]]:
    """
    Tokenize a MIDI file with explicit track delimiters.

    Instead of concatenating all tracks into a flat sequence, this function
    preserves track boundaries with TRACK_START/TRACK_END tokens and adds
    BAR_START markers for cross-track timing synchronization.

    Args:
        tokenizer: The REMI tokenizer
        midi_path: Path to the MIDI file
        max_tracks: Maximum number of tracks to include
        use_tags: Whether to prepend conditioning tags
        midi_root: Root directory for MIDI files (for artist folder detection)
        metadata: Loaded JSON metadata dict for tag lookup

    Returns:
        Tuple of:
        - tokens: Complete token sequence with track delimiters
        - track_infos: List of dicts with track metadata
    """
    from ..model.multitrack_utils import infer_track_type
    from .core import get_tag_tokens
    from .tag_inference import infer_tags_from_path

    score = Score(str(midi_path))
    score = trim_leading_silence(score)

    if not score.tracks:
        raise ValueError(f"No tracks found in {midi_path}")

    all_tokens = []
    track_infos = []

    # Add conditioning tags if enabled
    if use_tags:
        tags = infer_tags_from_path(midi_path, midi_root=midi_root, metadata=metadata)
        tag_tokens = get_tag_tokens(tokenizer)
        for tag in tags:
            if tag in tag_tokens:
                all_tokens.append(tag_tokens[tag])

    # Add BOS token (miditok names it "BOS_None")
    bos_id = tokenizer.vocab.get("BOS_None", tokenizer.vocab.get("BOS"))
    if bos_id is not None:
        all_tokens.append(bos_id)

    # Get special token IDs
    track_start_id = tokenizer.vocab.get("TRACK_START")
    track_end_id = tokenizer.vocab.get("TRACK_END")
    bar_start_id = tokenizer.vocab.get("BAR_START")

    # Tokenize ONCE from the trimmed score
    raw_tokens = tokenizer(score)

    if isinstance(raw_tokens, list) and len(raw_tokens) > 0:
        # Already per-track — use directly
        per_track_ids = []
        for t in raw_tokens:
            per_track_ids.append(t.ids if hasattr(t, 'ids') else t)
        return _build_from_per_track(
            per_track_ids, score, all_tokens, tokenizer,
            track_start_id, track_end_id, bar_start_id, max_tracks,
        )

    if hasattr(raw_tokens, 'ids'):
        combined_ids = raw_tokens.ids
    else:
        raise ValueError(f"No tokens from {midi_path}")

    # Build reverse vocab for splitting
    id_to_token = {tid: name for name, tid in tokenizer.vocab.items()}

    # Filter BOS/EOS from combined stream (we add them manually)
    bos_eos_ids = set()
    for name in ("BOS_None", "BOS", "EOS_None", "EOS"):
        tid = tokenizer.vocab.get(name)
        if tid is not None:
            bos_eos_ids.add(tid)
    combined_ids = [t for t in combined_ids if t not in bos_eos_ids]

    def _is_context_token(name: str) -> bool:
        """Tokens that mark time position and apply to all tracks."""
        return (name.startswith("Bar_") or name == "Bar"
                or name.startswith("Position_") or name.startswith("TimeSig_"))

    # Group tokens by program number from the interleaved stream.
    # Context tokens (Bar, Position, TimeSig) are duplicated to every
    # track that has notes in that time slot.
    from collections import OrderedDict
    program_tracks: OrderedDict[int, list[int]] = OrderedDict()
    current_program = 0
    pending_context: list[int] = []  # context tokens waiting to be assigned

    for token_id in combined_ids:
        token_name = id_to_token.get(token_id, "")
        if token_name.startswith("Program_"):
            try:
                current_program = int(token_name.split("_")[1])
            except (ValueError, IndexError):
                current_program = 0
            # Flush pending context to this track
            track = program_tracks.setdefault(current_program, [])
            track.extend(pending_context)
            pending_context = []
            track.append(token_id)
        elif _is_context_token(token_name):
            # Buffer context — it will be flushed to the next Program's track.
            # Also add to all existing tracks so every track gets bar/position markers.
            for track in program_tracks.values():
                track.append(token_id)
            pending_context.append(token_id)
        else:
            # Note content (Pitch, Velocity, Duration, etc.)
            program_tracks.setdefault(current_program, []).append(token_id)

    track_chunks = list(program_tracks.items())

    # Build output with track delimiters
    for track_idx, (program, chunk_ids) in enumerate(track_chunks[:max_tracks]):
        track_start_pos = len(all_tokens)
        bar_positions = []

        if track_start_id is not None:
            all_tokens.append(track_start_id)

        # Infer track type from score track if available
        track_type = "other"
        if track_idx < len(score.tracks):
            track_type = infer_track_type(score.tracks[track_idx], program)

        track_type_token = f"TRACKTYPE_{track_type.upper()}"
        if track_type_token in tokenizer.vocab:
            all_tokens.append(tokenizer.vocab[track_type_token])

        # Add the actual music tokens, inserting BAR_START markers
        for token_id in chunk_ids:
            token_name = id_to_token.get(token_id, "")
            if token_name.startswith("Bar_") or token_name == "Bar":
                if bar_start_id is not None:
                    bar_positions.append(len(all_tokens))
                    all_tokens.append(bar_start_id)
            all_tokens.append(token_id)

        if track_end_id is not None:
            all_tokens.append(track_end_id)

        track_infos.append({
            'track_idx': track_idx,
            'instrument': program,
            'track_type': track_type,
            'start_token_pos': track_start_pos,
            'end_token_pos': len(all_tokens),
            'bar_positions': bar_positions,
        })

    # Add EOS token (miditok names it "EOS_None")
    eos_id = tokenizer.vocab.get("EOS_None", tokenizer.vocab.get("EOS"))
    if eos_id is not None:
        all_tokens.append(eos_id)

    return all_tokens, track_infos


def tokens_to_multitrack_midi(
    tokenizer,
    tokens: list[int],
    output_path: str,
):
    """
    Convert multi-track token sequence back to MIDI file.

    Parses TRACK_START/TRACK_END delimiters and decodes each track separately,
    then combines them into a single multi-track MIDI file.

    Args:
        tokenizer: The REMI tokenizer
        tokens: Token sequence with track delimiters
        output_path: Where to save the MIDI file
    """
    from .core import get_tag_tokens, MULTITRACK_TOKENS, TRACK_TYPE_TOKENS

    # Get special token IDs
    track_start_id = tokenizer.vocab.get("TRACK_START")
    track_end_id = tokenizer.vocab.get("TRACK_END")
    bar_start_id = tokenizer.vocab.get("BAR_START")
    bos_id = tokenizer.vocab.get("BOS_None", tokenizer.vocab.get("BOS"))
    eos_id = tokenizer.vocab.get("EOS_None", tokenizer.vocab.get("EOS"))

    # Get all special tokens to filter out
    tag_token_ids = set(get_tag_tokens(tokenizer).values())
    multitrack_token_ids = set()
    for token_name in MULTITRACK_TOKENS + TRACK_TYPE_TOKENS:
        if token_name in tokenizer.vocab:
            multitrack_token_ids.add(tokenizer.vocab[token_name])

    special_ids = tag_token_ids | multitrack_token_ids
    if bos_id is not None:
        special_ids.add(bos_id)
    if eos_id is not None:
        special_ids.add(eos_id)

    # Parse tokens into separate tracks
    tracks_tokens = []
    current_track = []
    in_track = False

    for token in tokens:
        if token == track_start_id:
            in_track = True
            current_track = []
        elif token == track_end_id:
            if current_track:
                # Filter out special tokens before decoding
                filtered = [t for t in current_track if t not in special_ids]
                if filtered:
                    tracks_tokens.append(filtered)
            in_track = False
            current_track = []
        elif in_track:
            # Skip BAR_START tokens (our custom markers, not miditok's)
            if token != bar_start_id:
                current_track.append(token)

    # If no explicit tracks found, treat entire sequence as one track
    if not tracks_tokens:
        filtered = [t for t in tokens if t not in special_ids]
        if filtered:
            tracks_tokens.append(filtered)

    if not tracks_tokens:
        raise ValueError("No valid tokens to decode after filtering")

    # Decode each track
    vocab_size = len(tokenizer)
    id_to_token = {tid: name for name, tid in tokenizer.vocab.items()}

    try:
        # Filter tokens to valid vocabulary range
        valid_tracks = []
        for track_tokens in tracks_tokens:
            valid = [t for t in track_tokens if 0 <= t < vocab_size]
            if valid:
                valid_tracks.append(valid)

        if not valid_tracks:
            raise ValueError("No valid tokens after vocabulary filtering")

        # Normalize Program tokens within each logical track so miditok
        # decodes each one as a single instrument instead of splitting
        # into one sub-track per unique program number.
        for i, track_tokens in enumerate(valid_tracks):
            first_program_id = None
            for t in track_tokens:
                token_name = id_to_token.get(t, "")
                if token_name.startswith("Program_"):
                    first_program_id = t
                    break
            if first_program_id is not None:
                valid_tracks[i] = [
                    first_program_id if id_to_token.get(t, "").startswith("Program_") else t
                    for t in track_tokens
                ]

        # Decode each track separately and merge into single MIDI
        merged_midi = None
        for track_tokens in valid_tracks:
            # decode() expects a flat 1D list, not a list of lists
            track_midi = tokenizer.decode(track_tokens)
            if merged_midi is None:
                merged_midi = track_midi
            else:
                # Add tracks from this MIDI to the merged one
                for track in track_midi.tracks:
                    merged_midi.tracks.append(track)

        merged_midi = humanize_midi(merged_midi)
        merged_midi.dump_midi(output_path)
        print(f"Multi-track MIDI saved to {output_path} ({len(valid_tracks)} tracks)")

    except Exception as e:
        # Fallback: try decoding concatenated tokens
        print(f"Warning: Multi-track decode failed ({e}), trying single-track fallback")
        all_tokens = []
        for track_tokens in tracks_tokens:
            all_tokens.extend(track_tokens)

        valid = [t for t in all_tokens if 0 <= t < vocab_size and t not in special_ids]
        if not valid:
            raise ValueError("No valid tokens to decode")

        midi = tokenizer.decode(valid)
        midi = humanize_midi(midi)
        midi.dump_midi(output_path)
        print(f"MIDI saved to {output_path} (single-track fallback)")
