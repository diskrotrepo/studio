"""MIDI datasets for training."""

import torch
from torch.utils.data import Dataset


class MIDIDataset(Dataset):
    """Dataset of tokenized MIDI sequences."""

    def __init__(self, token_sequences: list[list[int]], seq_length: int = 512):
        self.seq_length = seq_length
        self.samples = []

        # Flatten all sequences and create overlapping chunks
        for tokens in token_sequences:
            # Create training samples with stride for overlap
            stride = seq_length * 3 // 4
            for i in range(0, len(tokens) - seq_length, stride):
                self.samples.append(tokens[i : i + seq_length + 1])  # +1 for target

    def __len__(self):
        return len(self.samples)

    def __getitem__(self, idx):
        tokens = self.samples[idx]

        # Pad to seq_length + 1 and mask padded target positions
        orig_len = len(tokens)
        target_len = self.seq_length + 1
        if orig_len < target_len:
            tokens = tokens + [0] * (target_len - orig_len)

        x = torch.tensor(tokens[:-1], dtype=torch.long)
        y = torch.tensor(tokens[1:], dtype=torch.long)

        if orig_len < target_len:
            y[max(orig_len - 1, 0):] = -100

        return x, y


class MultiTrackMIDIDataset(Dataset):
    """
    Dataset for multi-track MIDI sequences with track IDs and bar positions.

    Each sample includes:
    - tokens: Input token sequence
    - track_ids: Track ID for each token (-1 for non-track, 0+ for tracks)
    - bar_positions: Bar number for each token (for cross-track attention)
    """

    def __init__(
        self,
        token_sequences: list,
        seq_length: int = 8192,
        max_tracks: int = 16,
        vocab: dict = None,
    ):
        """
        Initialize multi-track dataset.

        Args:
            token_sequences: List of tuples from tokenize_multitrack_midi.
                Can be either:
                - (tokens, track_infos) - old format, will compute track_ids/bar_positions
                - (tokens, track_infos, track_ids, bar_positions) - new format with pre-computed data
            seq_length: Maximum sequence length for training samples
            max_tracks: Maximum number of tracks to support
            vocab: Tokenizer vocabulary (only needed for old format)
        """
        self.seq_length = seq_length
        self.max_tracks = max_tracks
        self.samples = []

        # Check format of first sequence to determine if pre-computed
        if token_sequences and len(token_sequences[0]) == 4:
            # New format: (tokens, track_infos, track_ids, bar_positions)
            for tokens, track_infos, track_ids, bar_positions in token_sequences:
                samples = self._create_samples(
                    tokens, track_ids, bar_positions, track_infos
                )
                self.samples.extend(samples)
        else:
            # Old format: (tokens, track_infos) - compute at runtime
            from ..model.multitrack_utils import compute_track_ids, compute_time_positions

            if vocab is None:
                raise ValueError(
                    "vocab required for old cache format without pre-computed track data"
                )

            for tokens, track_infos in token_sequences:
                track_ids = compute_track_ids(tokens, vocab, max_tracks)
                time_positions = compute_time_positions(tokens, vocab)
                bar_positions = [pos[0] for pos in time_positions]
                samples = self._create_samples(
                    tokens, track_ids, bar_positions, track_infos
                )
                self.samples.extend(samples)

    def _create_samples(
        self,
        tokens: list[int],
        track_ids: list[int],
        bar_positions: list[int],
        track_infos: list[dict],
    ) -> list[dict]:
        """Create training samples, respecting track boundaries where possible."""
        samples = []

        # If sequence fits in one sample, use it directly
        if len(tokens) <= self.seq_length:
            samples.append(
                {
                    "tokens": tokens,
                    "track_ids": track_ids,
                    "bar_positions": bar_positions,
                }
            )
            return samples

        # Find good split points (track boundaries, bar boundaries)
        split_points = self._find_split_points(tokens, track_infos)

        # Create overlapping windows
        stride = self.seq_length // 2
        for start in range(0, len(tokens) - self.seq_length, stride):
            end = start + self.seq_length + 1  # +1 for target

            # Try to adjust to nearest split point
            adjusted_start = self._adjust_to_split_point(start, split_points)
            adjusted_end = min(adjusted_start + self.seq_length + 1, len(tokens))

            if adjusted_end - adjusted_start < self.seq_length // 2:
                # Window too small after adjustment, use original
                adjusted_start = start
                adjusted_end = end

            samples.append(
                {
                    "tokens": tokens[adjusted_start:adjusted_end],
                    "track_ids": track_ids[adjusted_start:adjusted_end],
                    "bar_positions": bar_positions[adjusted_start:adjusted_end],
                }
            )

        return samples

    def _find_split_points(
        self, tokens: list[int], track_infos: list[dict]
    ) -> list[int]:
        """Find token positions that are good places to split (track/bar boundaries)."""
        split_points = [0]

        for info in track_infos:
            split_points.append(info["start_token_pos"])
            split_points.extend(info["bar_positions"])
            split_points.append(info["end_token_pos"])

        split_points.append(len(tokens))
        return sorted(set(split_points))

    def _adjust_to_split_point(self, pos: int, split_points: list[int]) -> int:
        """Adjust position to nearest split point."""
        # Find closest split point
        closest = min(split_points, key=lambda x: abs(x - pos))
        # Only adjust if within reasonable distance
        if abs(closest - pos) < self.seq_length // 4:
            return closest
        return pos

    def __len__(self):
        return len(self.samples)

    def __getitem__(self, idx):
        sample = self.samples[idx]
        tokens = sample["tokens"]
        track_ids = sample["track_ids"]
        bar_positions = sample["bar_positions"]

        # Track original length before padding so we can mask loss on padded positions
        orig_len = len(tokens)

        # Ensure we have enough tokens for input and target
        if orig_len < 2:
            tokens = tokens + [0] * (2 - orig_len)
            track_ids = track_ids + [-1] * (2 - len(track_ids))
            bar_positions = bar_positions + [0] * (2 - len(bar_positions))

        # Pad to seq_length + 1 to ensure consistent batch sizes
        target_len = self.seq_length + 1
        if len(tokens) < target_len:
            pad_len = target_len - len(tokens)
            tokens = tokens + [0] * pad_len
            track_ids = track_ids + [-1] * pad_len
            bar_positions = bar_positions + [0] * pad_len

        x = torch.tensor(tokens[:-1], dtype=torch.long)
        y = torch.tensor(tokens[1:], dtype=torch.long)
        t_ids = torch.tensor(track_ids[:-1], dtype=torch.long)
        bars = torch.tensor(bar_positions[:-1], dtype=torch.long)

        # Mark padded target positions with -100 so cross_entropy ignores them
        if orig_len < target_len:
            y[max(orig_len - 1, 0):] = -100

        return x, y, t_ids, bars
