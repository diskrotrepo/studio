"""
Pre-training data validation gate.

Validates token cache data before training starts and blocks on critical issues
that would cause silent model failures (broken attention masks, embedding crashes,
corrupted padding).

Called automatically from training CLI after cache loading, before dataset creation.
"""

import logging
from collections import Counter
from dataclasses import dataclass, field
from enum import Enum

from ..diagnose import _extract_tokens, _get_special_token_id, _percentile


class Severity(Enum):
    FATAL = "FATAL"
    WARNING = "WARNING"


@dataclass
class ValidationIssue:
    check_name: str
    severity: Severity
    message: str
    details: dict = field(default_factory=dict)


@dataclass
class ValidationReport:
    issues: list[ValidationIssue] = field(default_factory=list)
    stats: dict = field(default_factory=dict)

    @property
    def has_fatal(self) -> bool:
        return any(i.severity == Severity.FATAL for i in self.issues)

    @property
    def warnings(self) -> list[ValidationIssue]:
        return [i for i in self.issues if i.severity == Severity.WARNING]

    @property
    def fatals(self) -> list[ValidationIssue]:
        return [i for i in self.issues if i.severity == Severity.FATAL]


def _check_special_tokens(vocab, is_multitrack, report):
    """Check 1: Verify critical special tokens exist in vocabulary."""
    bos_id = _get_special_token_id(vocab, "BOS")
    eos_id = _get_special_token_id(vocab, "EOS")

    if bos_id is None:
        report.issues.append(ValidationIssue(
            check_name="special_tokens",
            severity=Severity.WARNING,
            message="BOS token not found in vocabulary. Sequences may lack start marker.",
        ))
    if eos_id is None:
        report.issues.append(ValidationIssue(
            check_name="special_tokens",
            severity=Severity.WARNING,
            message="EOS token not found in vocabulary. Sequences may lack end marker.",
        ))

    if is_multitrack:
        track_start_id = _get_special_token_id(vocab, "TRACK_START")
        track_end_id = _get_special_token_id(vocab, "TRACK_END")
        bar_start_id = _get_special_token_id(vocab, "BAR_START")

        if track_start_id is None:
            report.issues.append(ValidationIssue(
                check_name="special_tokens",
                severity=Severity.FATAL,
                message=(
                    "TRACK_START not found in vocabulary. compute_track_ids will "
                    "return all -1s and multitrack attention will be completely broken. "
                    "Re-run pretokenization with a tokenizer that includes multitrack tokens."
                ),
            ))
        if track_end_id is None:
            report.issues.append(ValidationIssue(
                check_name="special_tokens",
                severity=Severity.FATAL,
                message=(
                    "TRACK_END not found in vocabulary. compute_track_ids will "
                    "return all -1s and multitrack attention will be completely broken. "
                    "Re-run pretokenization with a tokenizer that includes multitrack tokens."
                ),
            ))
        if bar_start_id is None:
            report.issues.append(ValidationIssue(
                check_name="special_tokens",
                severity=Severity.FATAL,
                message=(
                    "BAR_START not found in vocabulary. Bar positions cannot be computed "
                    "and cross-track attention will be broken. "
                    "Re-run pretokenization with a tokenizer that includes multitrack tokens."
                ),
            ))


def _check_token_bounds(token_sequences, vocab_size, is_multitrack, report):
    """Check 2: Verify all token IDs are within [0, vocab_size)."""
    oob_count = 0
    oob_ids = set()
    total_tokens = 0

    for seq in token_sequences:
        tokens = _extract_tokens(seq, is_multitrack)
        total_tokens += len(tokens)
        for t in tokens:
            if t < 0 or t >= vocab_size:
                oob_count += 1
                if len(oob_ids) < 20:
                    oob_ids.add(t)

    report.stats["total_tokens"] = total_tokens

    if oob_count > 0:
        report.issues.append(ValidationIssue(
            check_name="token_bounds",
            severity=Severity.FATAL,
            message=(
                f"{oob_count:,} out-of-bounds tokens found in {total_tokens:,} total "
                f"(valid range: [0, {vocab_size})). Sample OOB IDs: {sorted(oob_ids)[:20]}. "
                f"This will crash nn.Embedding during training."
            ),
            details={"oob_count": oob_count, "oob_ids_sample": sorted(oob_ids)[:20]},
        ))


def _check_sequence_health(token_sequences, is_multitrack, report):
    """Check 3: Detect empty and degenerate sequences."""
    total = len(token_sequences)
    if total == 0:
        report.issues.append(ValidationIssue(
            check_name="sequence_health",
            severity=Severity.FATAL,
            message="No sequences in token cache. Nothing to train on.",
        ))
        return

    empty_count = 0
    short_count = 0

    for seq in token_sequences:
        length = len(_extract_tokens(seq, is_multitrack))
        if length == 0:
            empty_count += 1
        elif length < 10:
            short_count += 1

    if empty_count == total:
        report.issues.append(ValidationIssue(
            check_name="sequence_health",
            severity=Severity.FATAL,
            message="All sequences are empty (0 tokens). Nothing to train on.",
            details={"empty_count": empty_count},
        ))
    elif empty_count > 0:
        report.issues.append(ValidationIssue(
            check_name="sequence_health",
            severity=Severity.WARNING,
            message=f"{empty_count}/{total} sequences are empty (0 tokens).",
            details={"empty_count": empty_count},
        ))

    if short_count > total * 0.1:
        report.issues.append(ValidationIssue(
            check_name="sequence_health",
            severity=Severity.WARNING,
            message=(
                f"{short_count}/{total} sequences ({short_count / total * 100:.1f}%) "
                f"have fewer than 10 tokens."
            ),
            details={"short_count": short_count},
        ))


def _check_sequence_lengths(token_sequences, is_multitrack, max_seq_len, report):
    """Check 4: Report length distribution stats."""
    lengths = []
    for seq in token_sequences:
        lengths.append(len(_extract_tokens(seq, is_multitrack)))
    lengths.sort()

    if not lengths:
        return

    exceed_count = sum(1 for l in lengths if l > max_seq_len)
    report.stats["sequence_lengths"] = {
        "min": lengths[0],
        "max": lengths[-1],
        "mean": round(sum(lengths) / len(lengths), 1),
        "median": lengths[len(lengths) // 2],
        "p5": _percentile(lengths, 5),
        "p95": _percentile(lengths, 95),
        "exceeding_max_seq_len": exceed_count,
        "total": len(lengths),
    }


def _check_padding_token(vocab, report):
    """Check 5: Verify token ID 0 is PAD (used for padding in datasets)."""
    reverse_vocab = {v: k for k, v in vocab.items()}
    token_0_name = reverse_vocab.get(0)

    if token_0_name is None:
        report.issues.append(ValidationIssue(
            check_name="padding_token",
            severity=Severity.WARNING,
            message=(
                "Token ID 0 not found in vocabulary. Datasets pad with token 0 — "
                "if this ID is valid but unnamed, padding may inject meaningful tokens."
            ),
        ))
    elif "PAD" not in token_0_name.upper():
        report.issues.append(ValidationIssue(
            check_name="padding_token",
            severity=Severity.WARNING,
            message=(
                f"Token ID 0 maps to '{token_0_name}', not a PAD token. "
                f"Datasets pad short sequences with token 0, which will inject "
                f"'{token_0_name}' events into training data."
            ),
        ))


def _check_track_structure(token_sequences, vocab, max_tracks, sample_limit, is_multitrack, report):
    """Check 6: Validate track structure integrity (multitrack only)."""
    if not is_multitrack:
        return

    track_start_id = _get_special_token_id(vocab, "TRACK_START")
    track_end_id = _get_special_token_id(vocab, "TRACK_END")

    # If special tokens are missing, check 1 already flagged FATAL
    if track_start_id is None or track_end_id is None:
        return

    sample = token_sequences[:sample_limit]
    imbalanced_count = 0
    oob_track_ids = False
    non_monotonic_bars = False

    for seq in sample:
        # Extract based on format
        if isinstance(seq, (tuple, list)) and len(seq) >= 1:
            tokens = seq[0] if isinstance(seq[0], list) else list(seq[0])
        else:
            tokens = list(seq)

        # (a) Check TRACK_START/TRACK_END balance
        starts = tokens.count(track_start_id)
        ends = tokens.count(track_end_id)
        if starts != ends:
            imbalanced_count += 1

        # (b) Check track_id range (use pre-computed if available)
        if isinstance(seq, (tuple, list)) and len(seq) >= 3:
            track_ids = seq[2] if isinstance(seq[2], list) else list(seq[2])
            for tid in track_ids:
                if tid < -1 or tid >= max_tracks:
                    oob_track_ids = True
                    break

        # (c) Check bar position monotonicity (use pre-computed if available)
        if isinstance(seq, (tuple, list)) and len(seq) >= 4:
            track_ids = seq[2] if isinstance(seq[2], list) else list(seq[2])
            bar_positions = seq[3] if isinstance(seq[3], list) else list(seq[3])

            # Group bar positions by track and check monotonicity
            track_bars: dict[int, list[int]] = {}
            for tid, bar in zip(track_ids, bar_positions):
                if tid >= 0:  # Skip non-track tokens
                    track_bars.setdefault(tid, []).append(bar)

            for bars in track_bars.values():
                for i in range(1, len(bars)):
                    if bars[i] < bars[i - 1]:
                        non_monotonic_bars = True
                        break
                if non_monotonic_bars:
                    break

        if oob_track_ids and non_monotonic_bars:
            break  # No need to check more

    if imbalanced_count > 0:
        pct = imbalanced_count / len(sample) * 100
        severity = Severity.FATAL if pct > 20 else Severity.WARNING
        report.issues.append(ValidationIssue(
            check_name="track_balance",
            severity=severity,
            message=(
                f"{imbalanced_count}/{len(sample)} sampled sequences ({pct:.1f}%) have "
                f"unbalanced TRACK_START/TRACK_END counts. This produces incorrect track IDs."
            ),
            details={"imbalanced_count": imbalanced_count, "sample_size": len(sample)},
        ))

    if oob_track_ids:
        report.issues.append(ValidationIssue(
            check_name="track_id_range",
            severity=Severity.FATAL,
            message=(
                f"Pre-computed track_ids contain values outside [-1, {max_tracks - 1}]. "
                f"This will crash TrackEmbedding (nn.Embedding size {max_tracks + 1})."
            ),
        ))

    if non_monotonic_bars:
        report.issues.append(ValidationIssue(
            check_name="bar_position_monotonicity",
            severity=Severity.WARNING,
            message=(
                "Bar positions are not monotonically non-decreasing within at least one "
                "track. This causes tokens to attend to wrong bars in cross-track attention."
            ),
        ))


def _check_token_distribution(token_sequences, is_multitrack, sample_limit, report):
    """Check 7: Detect degenerate token distributions."""
    sample = token_sequences[:sample_limit]
    counter: Counter = Counter()
    total = 0

    for seq in sample:
        tokens = _extract_tokens(seq, is_multitrack)
        counter.update(tokens)
        total += len(tokens)

    if total == 0:
        return

    unique_count = len(counter)
    most_common_id, most_common_count = counter.most_common(1)[0]
    most_common_pct = most_common_count / total * 100

    report.stats["token_distribution"] = {
        "unique_tokens": unique_count,
        "most_common_token": most_common_id,
        "most_common_pct": round(most_common_pct, 1),
    }

    if most_common_pct > 90:
        report.issues.append(ValidationIssue(
            check_name="token_distribution",
            severity=Severity.WARNING,
            message=(
                f"Token {most_common_id} accounts for {most_common_pct:.1f}% of all tokens "
                f"in sampled sequences. Data may be degenerate."
            ),
        ))

    if unique_count < 20:
        report.issues.append(ValidationIssue(
            check_name="token_distribution",
            severity=Severity.WARNING,
            message=(
                f"Only {unique_count} unique tokens found across {len(sample)} sampled "
                f"sequences. Vocabulary is barely used."
            ),
        ))


def validate_training_data(
    token_sequences: list,
    vocab: dict,
    vocab_size: int,
    is_multitrack: bool,
    max_seq_len: int,
    max_tracks: int = 16,
    sample_limit: int = 5000,
    logger: logging.Logger | None = None,
) -> ValidationReport:
    """
    Validate token cache data before training starts.

    Runs 7 checks covering special tokens, token bounds, sequence health,
    length distribution, padding semantics, track structure, and token
    distribution. Returns a ValidationReport with FATAL and WARNING issues.

    Args:
        token_sequences: Raw sequences from load_token_cache()
        vocab: Tokenizer vocabulary dict (str -> int)
        vocab_size: Tokenizer vocab size (int)
        is_multitrack: Whether this is multitrack data
        max_seq_len: Model's positional encoding limit (config.seq_length)
        max_tracks: Maximum tracks the model supports
        sample_limit: Max sequences for expensive sampled checks
        logger: Optional logger for progress output

    Returns:
        ValidationReport with all issues found and informational stats
    """
    report = ValidationReport()
    mode = "multitrack" if is_multitrack else "single-track"

    if logger:
        logger.info(
            f"Validating {len(token_sequences):,} {mode} sequences "
            f"(vocab_size={vocab_size}, max_seq_len={max_seq_len}, max_tracks={max_tracks})..."
        )

    _check_special_tokens(vocab, is_multitrack, report)
    _check_token_bounds(token_sequences, vocab_size, is_multitrack, report)
    _check_sequence_health(token_sequences, is_multitrack, report)
    _check_sequence_lengths(token_sequences, is_multitrack, max_seq_len, report)
    _check_padding_token(vocab, report)
    _check_track_structure(token_sequences, vocab, max_tracks, sample_limit, is_multitrack, report)
    _check_token_distribution(token_sequences, is_multitrack, sample_limit, report)

    if logger:
        fatal_count = len(report.fatals)
        warn_count = len(report.warnings)
        if fatal_count == 0 and warn_count == 0:
            logger.info("Data validation PASSED (no issues)")
        else:
            logger.info(f"Data validation complete: {fatal_count} fatal, {warn_count} warnings")

    return report
