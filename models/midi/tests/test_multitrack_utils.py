"""Tests for multi-track MIDI utilities."""
from types import SimpleNamespace

import pytest
import torch

from midi.model.multitrack_utils import (
    compute_track_ids,
    compute_time_positions,
    build_cross_track_attention_mask_efficient,
    infer_track_type,
)


# Minimal vocab for testing special tokens
VOCAB = {
    "TRACK_START": 100,
    "TRACK_END": 101,
    "BAR_START": 102,
}


class TestComputeTrackIds:
    """Tests for track ID computation."""

    def test_empty_sequence(self):
        assert compute_track_ids([], VOCAB) == []

    def test_single_track(self):
        tokens = [100, 1, 2, 3, 101]  # TRACK_START, notes, TRACK_END
        ids = compute_track_ids(tokens, VOCAB)
        assert ids == [0, 0, 0, 0, 0]

    def test_two_tracks(self):
        tokens = [100, 1, 101, 100, 2, 101]
        ids = compute_track_ids(tokens, VOCAB)
        assert ids == [0, 0, 0, 1, 1, 1]

    def test_pre_track_tokens(self):
        tokens = [50, 51, 100, 1, 101]  # tags before first TRACK_START
        ids = compute_track_ids(tokens, VOCAB)
        assert ids[0] == -1
        assert ids[1] == -1
        assert ids[2] == 0

    def test_max_tracks_clamped(self):
        # 3 tracks with max_tracks=2 — third track clamps to id 1
        tokens = [100, 1, 101, 100, 2, 101, 100, 3, 101]
        ids = compute_track_ids(tokens, VOCAB, max_tracks=2)
        assert ids[6] == 1  # third TRACK_START clamped


class TestComputeTimePositions:
    """Tests for bar/position computation."""

    def test_empty_sequence(self):
        assert compute_time_positions([], VOCAB) == []

    def test_bar_increments(self):
        tokens = [1, 102, 2, 102, 3]  # note, BAR_START, note, BAR_START, note
        positions = compute_time_positions(tokens, VOCAB)
        bars = [p[0] for p in positions]
        assert bars == [0, 1, 1, 2, 2]

    def test_track_start_resets_bar(self):
        tokens = [100, 102, 1, 101, 100, 102, 2, 101]
        positions = compute_time_positions(tokens, VOCAB)
        bars = [p[0] for p in positions]
        # First track: TRACK_START(0), BAR_START(1), note(1), TRACK_END(1)
        # Second track resets: TRACK_START(0), BAR_START(1), note(1), TRACK_END(1)
        assert bars[4] == 0  # reset at second TRACK_START
        assert bars[5] == 1  # BAR_START increments


class TestCrossTrackAttentionMask:
    """Tests for efficient attention mask construction."""

    def test_output_shape(self):
        batch, seq = 2, 8
        track_ids = torch.zeros(batch, seq, dtype=torch.long)
        bar_pos = torch.zeros(batch, seq, dtype=torch.long)
        mask = build_cross_track_attention_mask_efficient(track_ids, bar_pos)
        assert mask.shape == (batch, seq, seq)

    def test_boolean_dtype(self):
        track_ids = torch.zeros(1, 4, dtype=torch.long)
        bar_pos = torch.zeros(1, 4, dtype=torch.long)
        mask = build_cross_track_attention_mask_efficient(track_ids, bar_pos)
        assert mask.dtype == torch.bool

    def test_same_track_causal(self):
        # Single track — mask should be lower-triangular (causal)
        # Convention: mask[i, j] = True when i >= j (can attend to past)
        track_ids = torch.zeros(1, 4, dtype=torch.long)
        bar_pos = torch.arange(4).unsqueeze(0)
        mask = build_cross_track_attention_mask_efficient(track_ids, bar_pos)
        # Later position (3) CAN attend to earlier position (0)
        assert mask[0, 3, 0]
        # Earlier position (0) CANNOT attend to later position (1)
        assert not mask[0, 0, 1]

    def test_cross_track_same_bar(self):
        # Two tracks, same bar — should allow cross-track attention
        track_ids = torch.tensor([[0, 0, 1, 1]])
        bar_pos = torch.tensor([[0, 1, 0, 1]])
        mask = build_cross_track_attention_mask_efficient(track_ids, bar_pos)
        # Track 1, bar 0 (pos 2) can attend to Track 0, bar 0 (pos 0)
        assert mask[0, 2, 0]
        # Track 1, bar 1 (pos 3) cannot attend to Track 0, bar 0 (pos 0)
        assert not mask[0, 3, 0]


class TestInferTrackType:
    """Tests for track type inference from program number."""

    def _make_track(self, is_drum=False, notes=None):
        return SimpleNamespace(is_drum=is_drum, notes=notes or [])

    def test_drums(self):
        assert infer_track_type(self._make_track(is_drum=True), 0) == "drums"

    def test_bass(self):
        assert infer_track_type(self._make_track(), 33) == "bass"

    def test_strings(self):
        assert infer_track_type(self._make_track(), 42) == "strings"

    def test_pad(self):
        assert infer_track_type(self._make_track(), 90) == "pad"

    def test_piano_defaults_melody(self):
        assert infer_track_type(self._make_track(), 0) == "melody"

    def test_unknown_program_returns_other(self):
        # Program 127 is FX
        assert infer_track_type(self._make_track(), 127) == "fx"
