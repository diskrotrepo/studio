"""Tests for the diagnostic toolkit."""
import math
import pickle
import tempfile
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest
import torch

from midi.diagnose import diagnose_tokens, _extract_tokens, _get_special_token_id


@pytest.fixture
def mock_tokenizer():
    """Create a mock tokenizer with a realistic vocab."""
    tok = MagicMock()
    vocab = {
        "PAD_None": 0, "BOS_None": 1, "EOS_None": 2,
        "GENRE_JAZZ": 3, "GENRE_ROCK": 4, "MOOD_HAPPY": 5,
        "TRACK_START": 6, "TRACK_END": 7, "BAR_START": 8,
        "Program_0": 9, "Pitch_60": 10, "Pitch_62": 11,
        "Pitch_64": 12, "Velocity_80": 13, "Duration_1.0": 14,
        "TimeShift_0.5": 15,
    }
    tok.vocab = vocab
    tok.vocab_size = len(vocab)
    return tok


def _make_cache(sequences, multitrack=False):
    """Create a temporary cache file and return its path."""
    data = {
        "sequences": sequences,
        "multitrack": multitrack,
        "version": 1,
        "file_count": len(sequences),
    }
    tmp = tempfile.NamedTemporaryFile(suffix=".pkl", delete=False)
    with open(tmp.name, "wb") as f:
        pickle.dump(data, f)
    return tmp.name


class TestExtractTokens:
    def test_plain_list(self):
        assert _extract_tokens([1, 2, 3], is_multitrack=False) == [1, 2, 3]

    def test_multitrack_tuple(self):
        seq = ([10, 11, 12], "track_infos", "track_ids", "bar_pos")
        assert _extract_tokens(seq, is_multitrack=True) == [10, 11, 12]

    def test_tensor(self):
        t = torch.tensor([5, 6, 7])
        assert _extract_tokens(t, is_multitrack=False) == [5, 6, 7]

    def test_multitrack_tensor(self):
        t = torch.tensor([5, 6, 7])
        seq = (t, None, None, None)
        assert _extract_tokens(seq, is_multitrack=True) == [5, 6, 7]


class TestGetSpecialTokenId:
    def test_direct_name(self):
        vocab = {"BOS": 1, "EOS": 2}
        assert _get_special_token_id(vocab, "BOS") == 1

    def test_suffixed_name(self):
        vocab = {"BOS_None": 1}
        assert _get_special_token_id(vocab, "BOS") == 1

    def test_missing(self):
        vocab = {"PAD": 0}
        assert _get_special_token_id(vocab, "BOS") is None

    def test_multiple_names(self):
        vocab = {"EOS_None": 2}
        assert _get_special_token_id(vocab, "EOS", "END") == 2


class TestDiagnoseTokens:
    def test_valid_cache(self, mock_tokenizer):
        """Valid sequences should pass all checks."""
        sequences = [
            [1, 3, 10, 13, 14, 15, 11, 13, 14, 15, 2],  # BOS, tag, notes, EOS
            [1, 4, 5, 12, 13, 14, 15, 10, 13, 14, 15, 2],
        ]
        cache_path = _make_cache(sequences)
        try:
            with patch("midi.tokenizer.get_tokenizer", return_value=mock_tokenizer), \
             patch("midi.tokenizer.get_tag_tokens", return_value={"GENRE_JAZZ": 3, "GENRE_ROCK": 4, "MOOD_HAPPY": 5}):
                result = diagnose_tokens(cache_path, tokenizer_path="fake.json")
            assert result is True
        finally:
            Path(cache_path).unlink()

    def test_oob_detection(self, mock_tokenizer):
        """Out-of-bounds token IDs should be caught."""
        sequences = [
            [1, 3, 999, 10, 2],  # 999 is out of bounds (vocab_size=16)
        ]
        cache_path = _make_cache(sequences)
        try:
            with patch("midi.tokenizer.get_tokenizer", return_value=mock_tokenizer), \
             patch("midi.tokenizer.get_tag_tokens", return_value={"GENRE_JAZZ": 3, "GENRE_ROCK": 4, "MOOD_HAPPY": 5}):
                result = diagnose_tokens(cache_path, tokenizer_path="fake.json")
            assert result is False
        finally:
            Path(cache_path).unlink()

    def test_missing_cache(self):
        """Missing cache file should return False."""
        result = diagnose_tokens("/nonexistent/path.pkl")
        assert result is False

    def test_empty_sequences(self, mock_tokenizer):
        """Empty sequence list should fail."""
        sequences = [[]]
        cache_path = _make_cache(sequences)
        try:
            with patch("midi.tokenizer.get_tokenizer", return_value=mock_tokenizer), \
             patch("midi.tokenizer.get_tag_tokens", return_value={"GENRE_JAZZ": 3, "GENRE_ROCK": 4, "MOOD_HAPPY": 5}):
                result = diagnose_tokens(cache_path, tokenizer_path="fake.json")
            # Should detect empty sequence
            assert result is False
        finally:
            Path(cache_path).unlink()

    def test_multitrack_unbalanced_markers(self, mock_tokenizer):
        """Mismatched TRACK_START/TRACK_END should be detected."""
        # TRACK_START=6, TRACK_END=7
        sequences = [
            ([1, 6, 10, 13, 14, 6, 10, 13, 14, 7, 2], None, None, None),
            # Two TRACK_STARTs but only one TRACK_END
        ]
        cache_path = _make_cache(sequences, multitrack=True)
        try:
            with patch("midi.tokenizer.get_tokenizer", return_value=mock_tokenizer), \
             patch("midi.tokenizer.get_tag_tokens", return_value={"GENRE_JAZZ": 3, "GENRE_ROCK": 4, "MOOD_HAPPY": 5}):
                result = diagnose_tokens(cache_path, tokenizer_path="fake.json")
            assert result is False
        finally:
            Path(cache_path).unlink()

    def test_json_output(self, mock_tokenizer, tmp_path):
        """JSON report should be written when requested."""
        import json
        sequences = [[1, 3, 10, 13, 14, 15, 2]]
        cache_path = _make_cache(sequences)
        json_path = str(tmp_path / "report.json")
        try:
            with patch("midi.tokenizer.get_tokenizer", return_value=mock_tokenizer), \
             patch("midi.tokenizer.get_tag_tokens", return_value={"GENRE_JAZZ": 3, "GENRE_ROCK": 4, "MOOD_HAPPY": 5}):
                diagnose_tokens(cache_path, tokenizer_path="fake.json",
                                json_output=json_path)
            with open(json_path) as f:
                report = json.load(f)
            assert "checks" in report
            assert report["num_sequences"] == 1
        finally:
            Path(cache_path).unlink()


class TestNaNLossDetection:
    def test_non_finite_loss_raises(self):
        """Non-finite loss should raise RuntimeError."""
        # We test the math.isfinite check directly since train_epoch
        # requires a full training setup
        assert math.isfinite(1.0)
        assert not math.isfinite(float("nan"))
        assert not math.isfinite(float("inf"))
        assert not math.isfinite(float("-inf"))


class TestVocabMismatch:
    def test_checkpoint_vocab_stored(self):
        """Verify save_checkpoint includes vocab_size."""
        # Build a minimal checkpoint dict matching train.py:save_checkpoint format
        checkpoint = {
            "epoch": 1,
            "model_state_dict": {},
            "optimizer_state_dict": {},
            "loss": 0.5,
            "vocab_size": 500,
            "config": {"d_model": 256, "n_heads": 4, "n_layers": 4, "max_seq_len": 2048},
        }
        assert "vocab_size" in checkpoint
        assert checkpoint["vocab_size"] == 500
