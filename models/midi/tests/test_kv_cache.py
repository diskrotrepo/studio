"""Tests for KV cache inference optimization."""

import torch
import pytest

from midi.model import (
    MultiHeadAttention,
    CrossTrackAttention,
    TransformerBlock,
    MultiTrackTransformerBlock,
    MusicTransformer,
    MultiTrackMusicTransformer,
)
from midi.model.multitrack_utils import (
    build_cross_track_attention_mask_efficient,
    build_cross_track_mask_row,
)


class TestMultiHeadAttentionCache:
    def test_cached_output_matches_full(self):
        """Prefill + cached step produces same output as full forward."""
        attn = MultiHeadAttention(d_model=64, n_heads=4, dropout=0.0)
        attn.eval()

        x = torch.randn(1, 10, 64)

        # Full forward (causal)
        out_full = attn(x)

        # Prefill on first 9 tokens
        _, past_kv = attn(x[:, :9], use_cache=True)

        # Cached step on token 10
        out_cached, _ = attn(x[:, 9:10], past_kv=past_kv, use_cache=True)

        # Output at position 10 should match
        torch.testing.assert_close(out_full[:, 9:10], out_cached, atol=1e-5, rtol=1e-5)

    def test_cache_shape(self):
        """KV cache tensors have correct shape."""
        attn = MultiHeadAttention(d_model=64, n_heads=4)
        x = torch.randn(2, 8, 64)
        _, past_kv = attn(x, use_cache=True)
        k, v = past_kv
        assert k.shape == (2, 4, 8, 16)  # (batch, heads, seq, head_dim)
        assert v.shape == (2, 4, 8, 16)

    def test_no_cache_returns_tensor(self):
        """Without use_cache, returns plain tensor (backward compat)."""
        attn = MultiHeadAttention(d_model=64, n_heads=4)
        x = torch.randn(1, 5, 64)
        out = attn(x)
        assert isinstance(out, torch.Tensor)
        assert out.shape == (1, 5, 64)

    def test_cache_grows_incrementally(self):
        """Cache accumulates across multiple steps."""
        attn = MultiHeadAttention(d_model=64, n_heads=4, dropout=0.0)
        attn.eval()

        x = torch.randn(1, 5, 64)
        _, past_kv = attn(x[:, :3], use_cache=True)
        assert past_kv[0].size(2) == 3

        _, past_kv = attn(x[:, 3:4], past_kv=past_kv, use_cache=True)
        assert past_kv[0].size(2) == 4

        _, past_kv = attn(x[:, 4:5], past_kv=past_kv, use_cache=True)
        assert past_kv[0].size(2) == 5


class TestCrossTrackAttentionCache:
    def test_cached_output_matches_full(self):
        """Cross-track attention: cached step matches full forward."""
        attn = CrossTrackAttention(d_model=64, n_heads=4, dropout=0.0)
        attn.eval()

        seq_len = 10
        x = torch.randn(1, seq_len, 64)

        # Simple lower-triangular mask (all True for causal)
        full_mask = torch.tril(torch.ones(1, seq_len, seq_len, dtype=torch.bool))

        out_full = attn(x, full_mask)

        # Prefill on first 9
        prefill_mask = full_mask[:, :9, :9]
        _, past_kv = attn(x[:, :9], prefill_mask, use_cache=True)

        # Cached step: mask row for position 9
        mask_row = full_mask[:, 9:10, :]  # (1, 1, 10)
        out_cached, _ = attn(x[:, 9:10], mask_row, past_kv=past_kv, use_cache=True)

        torch.testing.assert_close(out_full[:, 9:10], out_cached, atol=1e-5, rtol=1e-5)

    def test_no_cache_returns_tensor(self):
        """Without use_cache, returns plain tensor (backward compat)."""
        attn = CrossTrackAttention(d_model=64, n_heads=4)
        x = torch.randn(1, 5, 64)
        mask = torch.tril(torch.ones(1, 5, 5, dtype=torch.bool))
        out = attn(x, mask)
        assert isinstance(out, torch.Tensor)
        assert out.shape == (1, 5, 64)


class TestTransformerBlockCache:
    def test_cached_output_matches_full(self):
        """TransformerBlock: cached step matches full forward."""
        block = TransformerBlock(d_model=64, n_heads=4, dropout=0.0)
        block.eval()

        x = torch.randn(1, 10, 64)

        out_full = block(x)

        _, past_kv = block(x[:, :9], use_cache=True)
        out_cached, _ = block(x[:, 9:10], past_kv=past_kv, use_cache=True)

        torch.testing.assert_close(out_full[:, 9:10], out_cached, atol=1e-5, rtol=1e-5)

    def test_no_cache_returns_tensor(self):
        """Without use_cache, returns plain tensor."""
        block = TransformerBlock(d_model=64, n_heads=4)
        x = torch.randn(1, 5, 64)
        out = block(x)
        assert isinstance(out, torch.Tensor)


class TestMultiTrackTransformerBlockCache:
    def test_cached_output_matches_full_no_cross_track(self):
        """Block without cross-track: cached step matches full forward."""
        block = MultiTrackTransformerBlock(d_model=64, n_heads=4, dropout=0.0,
                                           use_cross_track=False)
        block.eval()

        x = torch.randn(1, 10, 64)

        out_full = block(x)

        _, past_kv = block(x[:, :9], use_cache=True)
        out_cached, _ = block(x[:, 9:10], past_kv=past_kv, use_cache=True)

        torch.testing.assert_close(out_full[:, 9:10], out_cached, atol=1e-5, rtol=1e-5)

    def test_cached_output_matches_full_with_cross_track(self):
        """Block with cross-track: cached step matches full forward."""
        block = MultiTrackTransformerBlock(d_model=64, n_heads=4, dropout=0.0,
                                           use_cross_track=True)
        block.eval()

        seq_len = 10
        x = torch.randn(1, seq_len, 64)
        full_mask = torch.tril(torch.ones(1, seq_len, seq_len, dtype=torch.bool))

        out_full = block(x, cross_track_mask=full_mask)

        prefill_mask = full_mask[:, :9, :9]
        _, past_kv = block(x[:, :9], cross_track_mask=prefill_mask, use_cache=True)

        mask_row = full_mask[:, 9:10, :]
        out_cached, _ = block(x[:, 9:10], cross_track_mask=mask_row,
                              past_kv=past_kv, use_cache=True)

        torch.testing.assert_close(out_full[:, 9:10], out_cached, atol=1e-5, rtol=1e-5)


class TestMusicTransformerCache:
    def test_cached_forward_matches_full(self):
        """Full model: cached forward matches non-cached."""
        model = MusicTransformer(vocab_size=100, d_model=64, n_heads=4,
                                 n_layers=2, max_seq_len=128, dropout=0.0)
        model.eval()

        x = torch.randint(0, 100, (1, 20))

        # Full forward
        logits_full = model(x)

        # Prefill + cached step
        _, past_kv = model(x[:, :19], use_cache=True)
        logits_cached, _ = model(x[:, 19:20], past_kv=past_kv, use_cache=True)

        torch.testing.assert_close(
            logits_full[:, 19:20], logits_cached, atol=1e-4, rtol=1e-4
        )

    def test_generate_with_cache_same_output(self):
        """Generate with cache produces same sequence as without (same seed)."""
        model = MusicTransformer(vocab_size=100, d_model=64, n_heads=4,
                                 n_layers=2, max_seq_len=128, dropout=0.0)
        model.eval()
        prompt = torch.randint(0, 100, (1, 5))

        torch.manual_seed(42)
        out_no_cache = model.generate(prompt.clone(), max_new_tokens=10,
                                      use_cache=False)

        torch.manual_seed(42)
        out_cache = model.generate(prompt.clone(), max_new_tokens=10,
                                   use_cache=True)

        assert torch.equal(out_no_cache, out_cache)


class TestMultiTrackMusicTransformerCache:
    def test_cached_forward_matches_full(self):
        """MultiTrack: cached output matches full forward."""
        model = MultiTrackMusicTransformer(
            vocab_size=100, d_model=64, n_heads=4, n_layers=4,
            max_seq_len=128, max_tracks=4, dropout=0.0,
        )
        model.eval()

        x = torch.randint(0, 100, (1, 15))
        track_ids = torch.zeros(1, 15, dtype=torch.long)
        bar_positions = torch.arange(15).unsqueeze(0)

        mask = build_cross_track_attention_mask_efficient(track_ids, bar_positions)

        # Full
        logits_full = model(x, track_ids=track_ids, cross_track_mask=mask)

        # Prefill + step
        prefill_mask = mask[:, :14, :14]
        _, past_kv = model(x[:, :14], track_ids=track_ids[:, :14],
                           cross_track_mask=prefill_mask, use_cache=True)

        mask_row = mask[:, 14:15, :]  # (1, 1, 15)
        logits_step, _ = model(x[:, 14:15], track_ids=track_ids[:, 14:15],
                               cross_track_mask=mask_row, past_kv=past_kv,
                               use_cache=True)

        torch.testing.assert_close(
            logits_full[:, 14:15], logits_step, atol=1e-4, rtol=1e-4
        )


class TestIncrementalMaskRow:
    def test_mask_row_matches_full(self):
        """Incremental mask row matches corresponding row of full mask."""
        track_ids = torch.tensor([[0, 0, 0, 1, 1, 1, 0, 0]])
        bar_positions = torch.tensor([[0, 0, 1, 0, 0, 1, 2, 2]])

        full_mask = build_cross_track_attention_mask_efficient(track_ids, bar_positions)
        row_mask = build_cross_track_mask_row(track_ids, bar_positions)

        # row_mask should equal the last row of full_mask
        torch.testing.assert_close(row_mask[:, 0, :], full_mask[:, -1, :])

    def test_mask_row_single_track(self):
        """Single track: all positions should be attended to (causal)."""
        track_ids = torch.tensor([[0, 0, 0, 0, 0]])
        bar_positions = torch.tensor([[0, 1, 2, 3, 4]])

        row_mask = build_cross_track_mask_row(track_ids, bar_positions)
        assert row_mask.shape == (1, 1, 5)
        assert row_mask.all()  # all True for same track

    def test_mask_row_non_track_tokens(self):
        """Non-track tokens (-1) should attend to everything."""
        track_ids = torch.tensor([[-1, -1, 0, 0, -1]])
        bar_positions = torch.tensor([[0, 0, 0, 1, 1]])

        full_mask = build_cross_track_attention_mask_efficient(track_ids, bar_positions)
        row_mask = build_cross_track_mask_row(track_ids, bar_positions)

        torch.testing.assert_close(row_mask[:, 0, :], full_mask[:, -1, :])


class TestSlidingWindowCache:
    def test_cache_invalidation_on_overflow(self):
        """Cache is invalidated when sequence exceeds max_seq_len."""
        model = MusicTransformer(
            vocab_size=100, d_model=64, n_heads=4, n_layers=2,
            max_seq_len=32, dropout=0.0,
        )
        model.eval()
        prompt = torch.randint(0, 100, (1, 5))

        # Generate 40 tokens (will exceed max_seq_len=32)
        output = model.generate(prompt, max_new_tokens=40, use_cache=True)
        assert output.shape == (1, 45)
