"""Tests for MusicTransformer model."""
import pytest
import torch

from midi.model import (
    MusicTransformer,
    MultiTrackMusicTransformer,
    PositionalEncoding,
    MultiHeadAttention,
    enable_lora,
    count_lora_parameters,
    _apply_sampling_filters,
)


class TestPositionalEncoding:
    """Tests for positional encoding."""

    def test_output_shape(self):
        """Test output shape matches input shape."""
        d_model = 64
        batch_size = 2
        seq_len = 32

        pe = PositionalEncoding(d_model=d_model, max_seq_len=128)
        x = torch.randn(batch_size, seq_len, d_model)
        out = pe(x)

        assert out.shape == x.shape

    def test_different_sequence_lengths(self):
        """Test encoding works with different sequence lengths."""
        d_model = 64
        pe = PositionalEncoding(d_model=d_model, max_seq_len=256)

        for seq_len in [16, 64, 128, 256]:
            x = torch.randn(1, seq_len, d_model)
            out = pe(x)
            assert out.shape == x.shape


class TestMultiHeadAttention:
    """Tests for multi-head attention."""

    def test_output_shape(self):
        """Test output shape matches input shape."""
        d_model = 64
        n_heads = 4
        batch_size = 2
        seq_len = 32

        attn = MultiHeadAttention(d_model=d_model, n_heads=n_heads)
        x = torch.randn(batch_size, seq_len, d_model)
        out = attn(x)

        assert out.shape == x.shape

    def test_d_model_divisibility(self):
        """Test that d_model must be divisible by n_heads."""
        with pytest.raises(AssertionError):
            MultiHeadAttention(d_model=64, n_heads=5)


class TestMusicTransformer:
    """Tests for single-track MusicTransformer."""

    @pytest.fixture
    def small_model(self):
        """Create a small model for testing."""
        return MusicTransformer(
            vocab_size=1000,
            d_model=64,
            n_heads=4,
            n_layers=2,
            max_seq_len=256,
        )

    def test_forward_shape(self, small_model):
        """Test forward pass output shape."""
        batch_size = 2
        seq_len = 32

        x = torch.randint(0, 1000, (batch_size, seq_len))
        out = small_model(x)

        assert out.shape == (batch_size, seq_len, 1000)

    def test_forward_with_different_seq_lengths(self, small_model):
        """Test forward with different sequence lengths."""
        batch_size = 2

        for seq_len in [8, 16, 32, 64]:
            x = torch.randint(0, 1000, (batch_size, seq_len))
            out = small_model(x)
            assert out.shape == (batch_size, seq_len, 1000)

    def test_model_has_expected_attributes(self, small_model):
        """Test model has expected configuration attributes."""
        assert hasattr(small_model, "d_model")
        assert hasattr(small_model, "n_heads")
        assert hasattr(small_model, "n_layers")
        assert small_model.d_model == 64
        assert small_model.n_heads == 4
        assert small_model.n_layers == 2


class TestMultiTrackMusicTransformer:
    """Tests for multi-track MusicTransformer."""

    @pytest.fixture
    def small_multitrack_model(self):
        """Create a small multi-track model for testing."""
        return MultiTrackMusicTransformer(
            vocab_size=1000,
            d_model=64,
            n_heads=4,
            n_layers=2,
            max_seq_len=256,
            max_tracks=4,
        )

    def test_forward_without_track_ids(self, small_multitrack_model):
        """Test forward pass works without track info (single track mode)."""
        batch_size = 2
        seq_len = 32

        x = torch.randint(0, 1000, (batch_size, seq_len))
        out = small_multitrack_model(x)

        assert out.shape == (batch_size, seq_len, 1000)

    def test_forward_with_track_ids(self, small_multitrack_model):
        """Test forward pass with track IDs."""
        batch_size = 2
        seq_len = 32

        x = torch.randint(0, 1000, (batch_size, seq_len))
        track_ids = torch.randint(0, 4, (batch_size, seq_len))
        out = small_multitrack_model(x, track_ids=track_ids)

        assert out.shape == (batch_size, seq_len, 1000)


class TestSamplingFilters:
    """Tests for _apply_sampling_filters edge cases."""

    def test_top_k_larger_than_vocab(self):
        """top_k larger than vocab size should not crash torch.topk."""
        logits = torch.randn(1, 10)  # vocab size 10
        token = _apply_sampling_filters(logits, top_k=50)  # top_k >> vocab
        assert token.shape == (1, 1)
        assert 0 <= token.item() < 10

    def test_suppress_tokens_out_of_range(self):
        """Out-of-range suppress_tokens IDs should be silently ignored."""
        logits = torch.randn(1, 10)  # vocab size 10
        token = _apply_sampling_filters(logits, suppress_tokens=[999, -1, 5])
        assert token.shape == (1, 1)
        assert token.item() != 5  # token 5 was validly suppressed (very likely)


class TestLoRA:
    """Tests for LoRA (Low-Rank Adaptation)."""

    @pytest.fixture
    def model_with_lora(self):
        """Create a model and enable LoRA."""
        model = MusicTransformer(
            vocab_size=1000,
            d_model=64,
            n_heads=4,
            n_layers=2,
            max_seq_len=256,
        )
        enable_lora(model, rank=4, alpha=8.0)
        return model

    def test_lora_reduces_trainable_params(self, model_with_lora):
        """Test that LoRA freezes most parameters."""
        lora_params, total_params, trainable_params = count_lora_parameters(
            model_with_lora
        )

        # LoRA params should be trainable
        assert lora_params > 0
        # Trainable params should be much smaller than total
        assert trainable_params < total_params
        # LoRA params should equal or be close to trainable params
        assert lora_params <= trainable_params

    def test_lora_forward_works(self, model_with_lora):
        """Test forward pass works with LoRA enabled."""
        batch_size = 2
        seq_len = 32

        x = torch.randint(0, 1000, (batch_size, seq_len))
        out = model_with_lora(x)

        assert out.shape == (batch_size, seq_len, 1000)
