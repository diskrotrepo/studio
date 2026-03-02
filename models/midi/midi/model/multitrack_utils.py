"""
Multi-track MIDI utilities.

Provides data structures and helper functions for multi-track music generation.
"""

import warnings
from dataclasses import dataclass

import torch


@dataclass
class TrackInfo:
    """Metadata about a single track in a sequence."""
    track_idx: int              # Track number (0-based)
    instrument: int             # MIDI program number (0-127)
    track_type: str             # Role: melody, bass, drums, chords, etc.
    start_token_pos: int        # Position in sequence where track starts
    end_token_pos: int          # Position in sequence where track ends
    bar_positions: list[int]    # Token positions where each bar starts


def compute_track_ids(
    tokens: list[int],
    vocab: dict,
    max_tracks: int = 16
) -> list[int]:
    """
    Compute track ID for each token in sequence.

    Args:
        tokens: List of token IDs
        vocab: Tokenizer vocabulary mapping token names to IDs
        max_tracks: Maximum number of tracks to support

    Returns:
        List of track IDs (0 to max_tracks-1, or -1 for non-track tokens like tags/BOS/EOS)
    """
    track_ids = []
    current_track = -1  # -1 for tokens outside tracks (tags, BOS, EOS)

    track_start_id = vocab.get("TRACK_START")
    track_end_id = vocab.get("TRACK_END")
    if track_start_id is None or track_end_id is None:
        warnings.warn(
            f"TRACK_START or TRACK_END not in vocab "
            f"(TRACK_START={track_start_id}, TRACK_END={track_end_id}). "
            f"All tokens will be assigned to track -1.",
            stacklevel=2,
        )
        return [-1] * len(tokens)

    for token in tokens:
        if token == track_start_id:
            current_track += 1
            current_track = min(current_track, max_tracks - 1)

        track_ids.append(current_track)

        if token == track_end_id:
            # Keep current_track for the TRACK_END token itself
            pass

    return track_ids


def compute_time_positions(
    tokens: list[int],
    vocab: dict,
) -> list[tuple[int, int]]:
    """
    Compute (bar_number, position_in_bar) for each token.

    This is used for cross-track attention alignment - tokens at the same
    bar position can attend to each other across tracks.

    Args:
        tokens: List of token IDs
        vocab: Tokenizer vocabulary mapping token names to IDs

    Returns:
        List of (bar, position) tuples for each token
    """
    time_positions = []
    current_bar = 0
    position_in_bar = 0

    bar_start_id = vocab.get("BAR_START")
    track_start_id = vocab.get("TRACK_START")
    if bar_start_id is None or track_start_id is None:
        warnings.warn(
            f"BAR_START or TRACK_START not in vocab "
            f"(BAR_START={bar_start_id}, TRACK_START={track_start_id}). "
            f"Time positions will all be (0, 0).",
            stacklevel=2,
        )
        return [(0, 0)] * len(tokens)

    for token in tokens:
        if token == track_start_id:
            # Reset bar counter at track boundaries
            current_bar = 0
            position_in_bar = 0
        elif token == bar_start_id:
            current_bar += 1
            position_in_bar = 0

        time_positions.append((current_bar, position_in_bar))
        position_in_bar += 1

    return time_positions


def build_cross_track_attention_mask(
    track_ids: torch.Tensor,
    time_positions: torch.Tensor,
    causal: bool = True
) -> torch.Tensor:
    """
    Build attention mask for cross-track attention.

    Tokens can attend to:
    1. Past tokens in the same track (causal self-attention)
    2. Tokens in other tracks at the same bar position (non-causal cross-track)

    Args:
        track_ids: (batch, seq_len) tensor of track IDs
        time_positions: (batch, seq_len) tensor of bar numbers
        causal: Whether to enforce causal masking within tracks

    Returns:
        Attention mask of shape (batch, seq_len, seq_len) where True = can attend
    """
    batch_size, seq_len = track_ids.shape
    device = track_ids.device

    # Expand for broadcasting: (batch, seq_len, 1) vs (batch, 1, seq_len)
    track_i = track_ids.unsqueeze(2)  # (batch, seq_len, 1)
    track_j = track_ids.unsqueeze(1)  # (batch, 1, seq_len)

    time_i = time_positions.unsqueeze(2)  # (batch, seq_len, 1)
    time_j = time_positions.unsqueeze(1)  # (batch, 1, seq_len)

    # Same track mask
    same_track = (track_i == track_j)  # (batch, seq_len, seq_len)

    # Same bar position mask (for cross-track attention)
    same_time = (time_i == time_j)  # (batch, seq_len, seq_len)

    # Causal mask: position i can only attend to positions j <= i
    if causal:
        positions = torch.arange(seq_len, device=device)
        causal_mask = positions.unsqueeze(1) >= positions.unsqueeze(0)  # (seq_len, seq_len)
        causal_mask = causal_mask.unsqueeze(0).expand(batch_size, -1, -1)  # (batch, seq_len, seq_len)
    else:
        causal_mask = torch.ones(batch_size, seq_len, seq_len, dtype=torch.bool, device=device)

    # Final mask:
    # - Within same track: causal attention (only attend to past)
    # - Across tracks: only attend if same bar position
    mask = (same_track & causal_mask) | (~same_track & same_time)

    # Handle non-track tokens (track_id == -1): they can attend to everything before them
    non_track_i = (track_i == -1).squeeze(2)  # (batch, seq_len)
    non_track_j = (track_j == -1).squeeze(1)  # (batch, seq_len)

    # Non-track tokens use simple causal attention
    for b in range(batch_size):
        for i in range(seq_len):
            if non_track_i[b, i]:
                # This token is outside a track (tag/BOS/EOS)
                # Use causal attention to all previous tokens
                mask[b, i, :] = causal_mask[b, i, :]

    return mask


def build_cross_track_attention_mask_efficient(
    track_ids: torch.Tensor,
    bar_positions: torch.Tensor,
    causal_cross_track: bool = True,
) -> torch.Tensor:
    """
    Efficient vectorized version of cross-track attention mask building.

    Args:
        track_ids: (batch, seq_len) tensor of track IDs (0 to max_tracks-1, -1 for non-track)
        bar_positions: (batch, seq_len) tensor of bar numbers (0, 1, 2, ...)
        causal_cross_track: If True (default), cross-track attention is causal —
            tokens can only attend to same-bar tokens in other tracks that appear
            earlier in the sequence. This ensures training matches autoregressive
            generation where future tokens don't exist. If False, cross-track
            same-bar attention is bidirectional (legacy behavior).

    Returns:
        Attention mask of shape (batch, seq_len, seq_len) where True = can attend
    """
    batch_size, seq_len = track_ids.shape
    device = track_ids.device

    # Unsqueeze for pairwise comparisons — broadcasting avoids materialization
    track_i = track_ids.unsqueeze(2)   # (batch, seq_len, 1)
    track_j = track_ids.unsqueeze(1)   # (batch, 1, seq_len)

    bar_i = bar_positions.unsqueeze(2)   # (batch, seq_len, 1)
    bar_j = bar_positions.unsqueeze(1)   # (batch, 1, seq_len)

    # Build causal mask — (1, seq_len, seq_len) broadcasts over batch
    pos = torch.arange(seq_len, device=device)
    causal = (pos.unsqueeze(1) >= pos.unsqueeze(0)).unsqueeze(0)

    # Same track: use causal
    same_track = (track_i == track_j)

    # Different track, same bar: allow attention (with optional causal constraint)
    diff_track_same_bar = (track_i != track_j) & (bar_i == bar_j)
    if causal_cross_track:
        diff_track_same_bar = diff_track_same_bar & causal

    # Non-track tokens (-1): use causal to everything
    is_non_track_i = (track_i == -1)
    is_non_track_j = (track_j == -1)

    # Combine: can attend if:
    # 1. Same track AND causal (j <= i)
    # 2. Different track AND same bar (AND causal if causal_cross_track)
    # 3. Source is non-track AND causal
    # 4. Target is non-track AND causal
    mask = (
        (same_track & causal) |
        diff_track_same_bar |
        (is_non_track_i & causal) |
        (is_non_track_j & causal)
    )

    return mask


def build_cross_track_mask_row(
    track_ids: torch.Tensor,
    bar_positions: torch.Tensor,
    causal_cross_track: bool = True,
) -> torch.Tensor:
    """
    Build the cross-track attention mask for ONLY the last position.

    Used during cached generation to avoid O(n^2) full mask computation.
    Since the new token is the last position, the causal condition (j <= i)
    is satisfied for all previous positions, so causal_cross_track has no
    effect here (included for API consistency).

    Args:
        track_ids: (batch, total_len) tensor — all positions including new token
        bar_positions: (batch, total_len) tensor — all positions including new token
        causal_cross_track: Accepted for API consistency; has no effect since the
            last row is always causally valid.

    Returns:
        (batch, 1, total_len) boolean mask — the single row for the new token
    """
    # The new token is at the last position
    new_track = track_ids[:, -1:]       # (batch, 1)
    new_bar = bar_positions[:, -1:]     # (batch, 1)

    # Same track: can attend (causal always satisfied since new is last)
    same_track = (new_track == track_ids)              # (batch, total_len)

    # Different track, same bar: can attend
    diff_track_same_bar = (new_track != track_ids) & (new_bar == bar_positions)

    # Non-track tokens: can attend causally (always true here)
    is_non_track_new = (new_track == -1)               # (batch, 1)
    is_non_track_all = (track_ids == -1)               # (batch, total_len)

    mask_row = (
        same_track |
        diff_track_same_bar |
        is_non_track_new |  # (batch, 1) broadcasts to (batch, total_len)
        is_non_track_all
    )

    return mask_row.unsqueeze(1)  # (batch, 1, total_len)


def infer_track_type(track, program: int) -> str:
    """
    Infer track role from instrument and note patterns.

    Args:
        track: symusic Track object
        program: MIDI program number (0-127)

    Returns:
        Track type string matching TRACK_TYPE_TOKENS (lowercase)
    """
    # Drums are on channel 10 (or track.is_drum flag)
    if hasattr(track, 'is_drum') and track.is_drum:
        return "drums"

    # Percussive instruments (programs 112-119)
    if 112 <= program <= 119:
        return "percussion"

    # Bass instruments (programs 32-39)
    if 32 <= program <= 39:
        return "bass"

    # Synth Pad sounds (programs 88-95)
    if 88 <= program <= 95:
        return "pad"

    # Synth Lead sounds (programs 80-87)
    if 80 <= program <= 87:
        return "lead"

    # Synth Effects (programs 96-103)
    if 96 <= program <= 103:
        return "synth"

    # Sound Effects (programs 120-127)
    if 120 <= program <= 127:
        return "fx"

    # Organ (programs 16-23)
    if 16 <= program <= 23:
        return "organ"

    # Brass (programs 56-63)
    if 56 <= program <= 63:
        return "brass"

    # Reed/Woodwind (programs 64-79: reed 64-71, pipe 72-79)
    if 64 <= program <= 79:
        return "woodwind"

    # Strings (programs 40-47)
    if 40 <= program <= 47:
        return "strings"

    # String Ensembles (programs 48-51)
    if 48 <= program <= 51:
        return "strings"

    # Choir/Voice (programs 52-54)
    if 52 <= program <= 54:
        return "choir"

    # Orchestra Hit (program 55) - treat as FX
    if program == 55:
        return "fx"

    # Chromatic Percussion (programs 8-15)
    if 8 <= program <= 15:
        return "percussion"

    # Ethnic instruments (programs 104-111)
    if 104 <= program <= 111:
        return "melody"

    # Piano/keys (programs 0-7) - check polyphony to distinguish melody vs chords
    if 0 <= program <= 7:
        if hasattr(track, 'notes') and len(track.notes) > 0:
            avg_polyphony = _compute_average_polyphony(track)
            if avg_polyphony > 2.5:
                return "chords"
            else:
                return "melody"
        return "melody"

    # Guitar (programs 24-31)
    if 24 <= program <= 31:
        if hasattr(track, 'notes') and len(track.notes) > 0:
            avg_polyphony = _compute_average_polyphony(track)
            if avg_polyphony > 2.0:
                return "chords"
            else:
                return "melody"
        return "melody"

    return "other"


def _compute_average_polyphony(track) -> float:
    """Compute average number of simultaneous notes."""
    if not hasattr(track, 'notes') or len(track.notes) == 0:
        return 1.0

    notes = track.notes
    if len(notes) < 2:
        return 1.0

    # Count overlapping notes at each note onset
    overlaps = []
    for i, note in enumerate(notes):
        count = 1
        for other in notes:
            if other is note:
                continue
            # Check if other note overlaps with this note's start time
            if hasattr(note, 'start') and hasattr(other, 'start') and hasattr(other, 'end'):
                if other.start <= note.start < other.end:
                    count += 1
            elif hasattr(note, 'time') and hasattr(other, 'time') and hasattr(other, 'duration'):
                if other.time <= note.time < other.time + other.duration:
                    count += 1
        overlaps.append(count)

    return sum(overlaps) / len(overlaps) if overlaps else 1.0


def extract_track_infos(
    tokens: list[int],
    vocab: dict,
) -> list[TrackInfo]:
    """
    Extract TrackInfo metadata from a tokenized sequence.

    Args:
        tokens: List of token IDs
        vocab: Tokenizer vocabulary

    Returns:
        List of TrackInfo objects, one per track in the sequence
    """
    track_infos = []

    track_start_id = vocab.get("TRACK_START")
    track_end_id = vocab.get("TRACK_END")
    bar_start_id = vocab.get("BAR_START")

    # Reverse vocab to get token names from IDs
    id_to_token = {v: k for k, v in vocab.items()}

    current_track_idx = -1
    current_track_start = None
    current_instrument = 0
    current_track_type = "other"
    current_bar_positions = []

    for pos, token in enumerate(tokens):
        if token == track_start_id:
            current_track_idx += 1
            current_track_start = pos
            current_bar_positions = []

        elif token == track_end_id and current_track_start is not None:
            track_infos.append(TrackInfo(
                track_idx=current_track_idx,
                instrument=current_instrument,
                track_type=current_track_type,
                start_token_pos=current_track_start,
                end_token_pos=pos,
                bar_positions=current_bar_positions.copy(),
            ))
            current_track_start = None

        elif token == bar_start_id:
            current_bar_positions.append(pos)

        else:
            # Check for instrument/program tokens
            token_name = id_to_token.get(token, "")
            if token_name.startswith("Program_"):
                try:
                    current_instrument = int(token_name.split("_")[1])
                except (ValueError, IndexError):
                    pass
            elif token_name.startswith("TRACKTYPE_"):
                current_track_type = token_name.replace("TRACKTYPE_", "").lower()

    return track_infos
