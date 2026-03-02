"""
Transformer Building Blocks

Core layers shared by single-track and multi-track transformers.
"""

import math
import torch
import torch.nn as nn


class PositionalEncoding(nn.Module):
    """Sinusoidal positional encoding."""

    def __init__(self, d_model: int, max_seq_len: int = 16384, dropout: float = 0.1):
        super().__init__()
        self.dropout = nn.Dropout(p=dropout)

        # Create positional encoding matrix
        position = torch.arange(max_seq_len).unsqueeze(1)
        div_term = torch.exp(
            torch.arange(0, d_model, 2) * (-math.log(10000.0) / d_model)
        )

        pe = torch.zeros(max_seq_len, d_model)
        pe[:, 0::2] = torch.sin(position * div_term)
        pe[:, 1::2] = torch.cos(position * div_term)

        # Register as buffer (not a parameter, but moves with model)
        self.register_buffer("pe", pe.unsqueeze(0))

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """Add positional encoding to input."""
        x = x + self.pe[:, :x.size(1)]
        return self.dropout(x)


class MultiHeadAttention(nn.Module):
    """Multi-head self-attention with causal masking."""

    def __init__(self, d_model: int, n_heads: int, dropout: float = 0.1):
        super().__init__()
        assert d_model % n_heads == 0, "d_model must be divisible by n_heads"

        self.d_model = d_model
        self.n_heads = n_heads
        self.head_dim = d_model // n_heads

        self.qkv_proj = nn.Linear(d_model, 3 * d_model)
        self.out_proj = nn.Linear(d_model, d_model)
        self.dropout = nn.Dropout(dropout)

        self.scale = math.sqrt(self.head_dim)

    def forward(self, x: torch.Tensor, mask: torch.Tensor = None,
                past_kv: tuple[torch.Tensor, torch.Tensor] | None = None,
                use_cache: bool = False,
                cache_pos: int | None = None):
        batch_size, seq_len, _ = x.shape

        # Project to Q, K, V
        qkv = self.qkv_proj(x)
        qkv = qkv.reshape(batch_size, seq_len, 3, self.n_heads, self.head_dim)
        qkv = qkv.permute(2, 0, 3, 1, 4)  # (3, batch, heads, seq, head_dim)
        q, k, v = qkv[0], qkv[1], qkv[2]

        # Merge with cached K, V if available
        if past_kv is not None:
            if cache_pos is not None:
                # Static cache: write in-place, no allocation
                past_kv[0][:, :, cache_pos:cache_pos + seq_len] = k
                past_kv[1][:, :, cache_pos:cache_pos + seq_len] = v
                k = past_kv[0][:, :, :cache_pos + seq_len]
                v = past_kv[1][:, :, :cache_pos + seq_len]
                present_kv = past_kv
            else:
                k = torch.cat([past_kv[0], k], dim=2)
                v = torch.cat([past_kv[1], v], dim=2)
                present_kv = (k, v) if use_cache else None
        else:
            present_kv = (k, v) if use_cache else None

        if past_kv is not None:
            # Cached step: Q is latest position(s), all K/V are at or before current
            out = torch.nn.functional.scaled_dot_product_attention(
                q, k, v,
                attn_mask=None,
                dropout_p=0.0,
                is_causal=False,
            )
        else:
            # Training / prefill: full causal attention
            out = torch.nn.functional.scaled_dot_product_attention(
                q, k, v,
                attn_mask=None,
                dropout_p=self.dropout.p if self.training else 0.0,
                is_causal=True,
            )

        out = out.transpose(1, 2).reshape(batch_size, seq_len, self.d_model)
        out = self.out_proj(out)

        if use_cache:
            return out, present_kv
        return out


class FeedForward(nn.Module):
    """Position-wise feed-forward network."""

    def __init__(self, d_model: int, d_ff: int = None, dropout: float = 0.1):
        super().__init__()
        d_ff = d_ff or 4 * d_model

        self.net = nn.Sequential(
            nn.Linear(d_model, d_ff),
            nn.GELU(),
            nn.Dropout(dropout),
            nn.Linear(d_ff, d_model),
            nn.Dropout(dropout),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.net(x)


class TransformerBlock(nn.Module):
    """Single transformer decoder block."""

    def __init__(self, d_model: int, n_heads: int, dropout: float = 0.1):
        super().__init__()

        self.attn = MultiHeadAttention(d_model, n_heads, dropout)
        self.ff = FeedForward(d_model, dropout=dropout)
        self.ln1 = nn.LayerNorm(d_model)
        self.ln2 = nn.LayerNorm(d_model)
        self.dropout = nn.Dropout(dropout)

    def forward(self, x: torch.Tensor, mask: torch.Tensor = None,
                past_kv: tuple[torch.Tensor, torch.Tensor] | None = None,
                use_cache: bool = False,
                cache_pos: int | None = None):
        # Pre-norm architecture (more stable training)
        if use_cache:
            attn_out, present_kv = self.attn(self.ln1(x), mask,
                                             past_kv=past_kv, use_cache=True,
                                             cache_pos=cache_pos)
        else:
            attn_out = self.attn(self.ln1(x), mask)
            present_kv = None

        x = x + self.dropout(attn_out)
        x = x + self.dropout(self.ff(self.ln2(x)))

        if use_cache:
            return x, present_kv
        return x
