"""Tests for pre-training data validation gate."""
import pytest

from midi.training.validation import (
    Severity,
    ValidationReport,
    validate_training_data,
)


def _base_vocab():
    """Vocab with all special tokens present."""
    return {
        "PAD_None": 0, "BOS_None": 1, "EOS_None": 2,
        "GENRE_JAZZ": 3, "GENRE_ROCK": 4, "MOOD_HAPPY": 5,
        "TRACK_START": 6, "TRACK_END": 7, "BAR_START": 8,
        "Program_0": 9, "Pitch_60": 10, "Pitch_62": 11,
        "Pitch_64": 12, "Velocity_80": 13, "Duration_1.0": 14,
        "TimeShift_0.5": 15,
    }


def _valid_single_track_sequences():
    """Simple valid single-track sequences."""
    return [
        [1, 10, 13, 14, 15, 11, 13, 14, 15, 12, 13, 14, 15, 2],
        [1, 10, 13, 14, 15, 10, 13, 14, 15, 11, 13, 14, 15, 2],
        [1, 12, 13, 14, 15, 11, 13, 14, 15, 10, 13, 14, 15, 2],
    ]


def _valid_multitrack_sequences():
    """Valid multitrack sequences in 4-tuple format (tokens, track_infos, track_ids, bar_positions)."""
    tokens = [1, 6, 8, 10, 13, 14, 15, 7, 6, 8, 11, 13, 14, 15, 7, 2]
    track_ids = [-1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, -1]
    bar_positions = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    return [
        (tokens, None, track_ids, bar_positions),
        (tokens, None, track_ids, bar_positions),
        (tokens, None, track_ids, bar_positions),
    ]


class TestAllPass:
    def test_single_track_clean(self):
        vocab = _base_vocab()
        report = validate_training_data(
            _valid_single_track_sequences(), vocab, len(vocab),
            is_multitrack=False, max_seq_len=512,
        )
        assert not report.has_fatal
        # Only the token_distribution warning fires (small test data has < 20 unique tokens)
        non_dist_warns = [i for i in report.warnings if i.check_name != "token_distribution"]
        assert len(non_dist_warns) == 0

    def test_multitrack_clean(self):
        vocab = _base_vocab()
        report = validate_training_data(
            _valid_multitrack_sequences(), vocab, len(vocab),
            is_multitrack=True, max_seq_len=512,
        )
        assert not report.has_fatal
        non_dist_warns = [i for i in report.warnings if i.check_name != "token_distribution"]
        assert len(non_dist_warns) == 0


class TestSpecialTokens:
    def test_missing_track_start_fatal(self):
        vocab = _base_vocab()
        del vocab["TRACK_START"]
        report = validate_training_data(
            _valid_multitrack_sequences(), vocab, len(vocab),
            is_multitrack=True, max_seq_len=512,
        )
        fatal_names = [i.check_name for i in report.fatals]
        assert "special_tokens" in fatal_names

    def test_missing_track_end_fatal(self):
        vocab = _base_vocab()
        del vocab["TRACK_END"]
        report = validate_training_data(
            _valid_multitrack_sequences(), vocab, len(vocab),
            is_multitrack=True, max_seq_len=512,
        )
        fatal_names = [i.check_name for i in report.fatals]
        assert "special_tokens" in fatal_names

    def test_missing_bar_start_fatal(self):
        vocab = _base_vocab()
        del vocab["BAR_START"]
        report = validate_training_data(
            _valid_multitrack_sequences(), vocab, len(vocab),
            is_multitrack=True, max_seq_len=512,
        )
        fatal_names = [i.check_name for i in report.fatals]
        assert "special_tokens" in fatal_names

    def test_missing_bos_warning_single_track(self):
        vocab = _base_vocab()
        orig_size = len(vocab)
        del vocab["BOS_None"]
        report = validate_training_data(
            _valid_single_track_sequences(), vocab, orig_size,
            is_multitrack=False, max_seq_len=512,
        )
        assert not report.has_fatal
        warn_names = [i.check_name for i in report.warnings]
        assert "special_tokens" in warn_names

    def test_multitrack_tokens_not_checked_single_track(self):
        vocab = _base_vocab()
        orig_size = len(vocab)
        del vocab["TRACK_START"]
        del vocab["TRACK_END"]
        del vocab["BAR_START"]
        report = validate_training_data(
            _valid_single_track_sequences(), vocab, orig_size,
            is_multitrack=False, max_seq_len=512,
        )
        # Should NOT be fatal — multitrack tokens irrelevant for single-track
        assert not report.has_fatal


class TestTokenBounds:
    def test_oob_high_fatal(self):
        vocab = _base_vocab()
        seqs = [[1, 10, 999, 2]]  # 999 >= vocab_size
        report = validate_training_data(
            seqs, vocab, len(vocab),
            is_multitrack=False, max_seq_len=512,
        )
        fatal_names = [i.check_name for i in report.fatals]
        assert "token_bounds" in fatal_names

    def test_negative_token_fatal(self):
        vocab = _base_vocab()
        seqs = [[1, -5, 10, 2]]
        report = validate_training_data(
            seqs, vocab, len(vocab),
            is_multitrack=False, max_seq_len=512,
        )
        fatal_names = [i.check_name for i in report.fatals]
        assert "token_bounds" in fatal_names


class TestSequenceHealth:
    def test_all_empty_fatal(self):
        vocab = _base_vocab()
        seqs = [[], [], []]
        report = validate_training_data(
            seqs, vocab, len(vocab),
            is_multitrack=False, max_seq_len=512,
        )
        fatal_names = [i.check_name for i in report.fatals]
        assert "sequence_health" in fatal_names

    def test_no_sequences_fatal(self):
        vocab = _base_vocab()
        report = validate_training_data(
            [], vocab, len(vocab),
            is_multitrack=False, max_seq_len=512,
        )
        fatal_names = [i.check_name for i in report.fatals]
        assert "sequence_health" in fatal_names

    def test_many_short_warning(self):
        vocab = _base_vocab()
        # 12 sequences, 11 of which are short (< 10 tokens) = >10%
        seqs = [[1, 2, 3]] * 11 + [[1, 10, 13, 14, 15, 11, 13, 14, 15, 12, 13, 14, 15, 2]]
        report = validate_training_data(
            seqs, vocab, len(vocab),
            is_multitrack=False, max_seq_len=512,
        )
        warn_names = [i.check_name for i in report.warnings]
        assert "sequence_health" in warn_names


class TestSequenceLengths:
    def test_exceed_count_in_stats(self):
        vocab = _base_vocab()
        # All sequences exceed max_seq_len=10
        seqs = [list(range(16))] * 5  # All valid IDs, all length 16
        report = validate_training_data(
            seqs, vocab, len(vocab),
            is_multitrack=False, max_seq_len=10,
        )
        assert report.stats["sequence_lengths"]["exceeding_max_seq_len"] == 5
        assert report.stats["sequence_lengths"]["total"] == 5

    def test_none_exceed(self):
        vocab = _base_vocab()
        report = validate_training_data(
            _valid_single_track_sequences(), vocab, len(vocab),
            is_multitrack=False, max_seq_len=512,
        )
        assert report.stats["sequence_lengths"]["exceeding_max_seq_len"] == 0


class TestPaddingToken:
    def test_pad_token_ok(self):
        vocab = _base_vocab()  # token 0 = "PAD_None"
        report = validate_training_data(
            _valid_single_track_sequences(), vocab, len(vocab),
            is_multitrack=False, max_seq_len=512,
        )
        pad_warns = [i for i in report.warnings if i.check_name == "padding_token"]
        assert len(pad_warns) == 0

    def test_non_pad_token_0_warning(self):
        vocab = _base_vocab()
        del vocab["PAD_None"]
        vocab["Pitch_0"] = 0  # token 0 is now a pitch
        report = validate_training_data(
            _valid_single_track_sequences(), vocab, len(vocab),
            is_multitrack=False, max_seq_len=512,
        )
        warn_names = [i.check_name for i in report.warnings]
        assert "padding_token" in warn_names


class TestTrackStructure:
    def test_unbalanced_tracks_warning(self):
        vocab = _base_vocab()
        ts = vocab["TRACK_START"]
        te = vocab["TRACK_END"]
        # Missing TRACK_END for second track
        tokens = [1, ts, 8, 10, 13, te, ts, 11, 13, 2]
        track_ids = [-1, 0, 0, 0, 0, 0, 1, 1, 1, -1]
        bar_positions = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        seqs = [(tokens, None, track_ids, bar_positions)]
        report = validate_training_data(
            seqs, vocab, len(vocab),
            is_multitrack=True, max_seq_len=512,
        )
        issue_names = [i.check_name for i in report.issues]
        assert "track_balance" in issue_names

    def test_track_id_out_of_range_fatal(self):
        vocab = _base_vocab()
        tokens = [1, 6, 8, 10, 7, 2]
        track_ids = [-1, 20, 20, 20, 20, -1]  # 20 >= max_tracks=16
        bar_positions = [0, 0, 0, 0, 0, 0]
        seqs = [(tokens, None, track_ids, bar_positions)]
        report = validate_training_data(
            seqs, vocab, len(vocab),
            is_multitrack=True, max_seq_len=512, max_tracks=16,
        )
        fatal_names = [i.check_name for i in report.fatals]
        assert "track_id_range" in fatal_names

    def test_non_monotonic_bars_warning(self):
        vocab = _base_vocab()
        tokens = [1, 6, 8, 10, 8, 11, 7, 2]
        track_ids = [-1, 0, 0, 0, 0, 0, 0, -1]
        bar_positions = [0, 0, 1, 1, 0, 0, 0, 0]  # Bar goes 1 -> 0 (non-monotonic)
        seqs = [(tokens, None, track_ids, bar_positions)]
        report = validate_training_data(
            seqs, vocab, len(vocab),
            is_multitrack=True, max_seq_len=512,
        )
        warn_names = [i.check_name for i in report.warnings]
        assert "bar_position_monotonicity" in warn_names


class TestTokenDistribution:
    def test_degenerate_distribution_warning(self):
        vocab = _base_vocab()
        # 95% token 10, 5% token 11
        seqs = [[10] * 950 + [11] * 50]
        report = validate_training_data(
            seqs, vocab, len(vocab),
            is_multitrack=False, max_seq_len=2048,
        )
        warn_names = [i.check_name for i in report.warnings]
        assert "token_distribution" in warn_names

    def test_low_unique_tokens_warning(self):
        vocab = _base_vocab()
        # Only 5 unique tokens
        seqs = [[0, 1, 2, 3, 4] * 20]
        report = validate_training_data(
            seqs, vocab, len(vocab),
            is_multitrack=False, max_seq_len=512,
        )
        warn_names = [i.check_name for i in report.warnings]
        assert "token_distribution" in warn_names


class TestReportProperties:
    def test_has_fatal_mixed(self):
        report = ValidationReport()
        from midi.training.validation import ValidationIssue
        report.issues.append(ValidationIssue("a", Severity.WARNING, "warn"))
        assert not report.has_fatal
        report.issues.append(ValidationIssue("b", Severity.FATAL, "fatal"))
        assert report.has_fatal

    def test_fatals_and_warnings_lists(self):
        report = ValidationReport()
        from midi.training.validation import ValidationIssue
        report.issues.append(ValidationIssue("a", Severity.WARNING, "w1"))
        report.issues.append(ValidationIssue("b", Severity.FATAL, "f1"))
        report.issues.append(ValidationIssue("c", Severity.WARNING, "w2"))
        assert len(report.fatals) == 1
        assert len(report.warnings) == 2
