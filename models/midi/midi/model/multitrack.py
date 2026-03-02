"""
Multi-Track Music Transformer

Extends the base transformer with track embeddings and cross-track attention
for simultaneous multi-instrument generation.
"""

import logging
import math
import time
import warnings
import torch
import torch.nn as nn

from .layers import PositionalEncoding, MultiHeadAttention, FeedForward
from .sampling import _apply_sampling_filters

logger = logging.getLogger(__name__)


def _make_static_kv_multitrack(past_kv, max_len):
    """Convert multitrack dynamic KV cache to pre-allocated static buffers."""
    static = []
    for self_kv, cross_kv in past_kv:
        k, v = self_kv
        k_buf = torch.zeros(k.shape[0], k.shape[1], max_len, k.shape[3],
                            dtype=k.dtype, device=k.device)
        v_buf = torch.zeros_like(k_buf)
        k_buf[:, :, :k.size(2)] = k
        v_buf[:, :, :v.size(2)] = v
        static_self = [k_buf, v_buf]

        if cross_kv is not None:
            ck, cv = cross_kv
            ck_buf = torch.zeros(ck.shape[0], ck.shape[1], max_len, ck.shape[3],
                                 dtype=ck.dtype, device=ck.device)
            cv_buf = torch.zeros_like(ck_buf)
            ck_buf[:, :, :ck.size(2)] = ck
            cv_buf[:, :, :cv.size(2)] = cv
            static_cross = [ck_buf, cv_buf]
        else:
            static_cross = None

        static.append((static_self, static_cross))
    return static


class TrackEmbedding(nn.Module):
    """Learnable embeddings for track identity."""

    def __init__(self, max_tracks: int, d_model: int):
        super().__init__()
        # +1 for non-track tokens (track_id = -1 maps to index 0)
        self.embedding = nn.Embedding(max_tracks + 1, d_model)
        self.max_tracks = max_tracks

    def forward(self, track_ids: torch.Tensor) -> torch.Tensor:
        """
        Get track embeddings.

        Args:
            track_ids: (batch, seq_len) tensor with values -1 to max_tracks-1

        Returns:
            (batch, seq_len, d_model) track embeddings
        """
        # Shift track_ids so -1 maps to 0, 0 maps to 1, etc.
        shifted_ids = track_ids + 1
        return self.embedding(shifted_ids)


class CrossTrackAttention(nn.Module):
    """
    Attention mechanism that allows tokens to attend across tracks.

    Tokens can attend to:
    1. Past tokens in the same track (causal)
    2. Tokens in other tracks at the same bar position (non-causal)

    Uses PyTorch's scaled_dot_product_attention for memory efficiency.
    """

    def __init__(self, d_model: int, n_heads: int, dropout: float = 0.1):
        super().__init__()
        assert d_model % n_heads == 0, "d_model must be divisible by n_heads"

        self.d_model = d_model
        self.n_heads = n_heads
        self.head_dim = d_model // n_heads

        self.qkv_proj = nn.Linear(d_model, 3 * d_model)
        self.out_proj = nn.Linear(d_model, d_model)
        self.dropout_p = dropout

        self.scale = math.sqrt(self.head_dim)

    def forward(
        self,
        x: torch.Tensor,
        cross_track_mask: torch.Tensor,
        past_kv: tuple[torch.Tensor, torch.Tensor] | None = None,
        use_cache: bool = False,
        cache_pos: int | None = None,
    ):
        """
        Forward pass with cross-track attention mask.

        Args:
            x: (batch, seq_len, d_model) input tensor
            cross_track_mask: (batch, seq_len, seq_len) boolean mask where True = can attend.
                During cached steps: (batch, 1, total_len) single mask row for new token.
            past_kv: Cached (K, V) from previous steps
            use_cache: Whether to return updated (K, V) cache
            cache_pos: Position in static KV cache buffer (None for dynamic cache)

        Returns:
            (batch, seq_len, d_model) output tensor, or tuple of (output, (K, V)) if use_cache
        """
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

        # Convert boolean mask to float additive mask for SDPA.
        # Boolean masks disable Flash Attention; float masks enable the
        # memory-efficient attention kernel which is significantly faster.
        attn_mask = cross_track_mask.unsqueeze(1)  # (batch, 1, seq, seq)
        attn_mask = torch.where(attn_mask, 0.0, float('-inf')).to(dtype=q.dtype)

        # Use PyTorch's optimized SDPA (memory-efficient attention on CUDA)
        out = torch.nn.functional.scaled_dot_product_attention(
            q, k, v,
            attn_mask=attn_mask,
            dropout_p=self.dropout_p if self.training else 0.0,
            is_causal=False,  # We provide our own mask
        )

        out = out.transpose(1, 2).reshape(batch_size, seq_len, self.d_model)
        out = self.out_proj(out)

        if use_cache:
            return out, present_kv
        return out


class MultiTrackTransformerBlock(nn.Module):
    """
    Transformer block with both causal self-attention and cross-track attention.
    """

    def __init__(
        self,
        d_model: int,
        n_heads: int,
        dropout: float = 0.1,
        use_cross_track: bool = True,
    ):
        super().__init__()

        self.use_cross_track = use_cross_track

        # Standard causal self-attention
        self.self_attn = MultiHeadAttention(d_model, n_heads, dropout)
        self.ln1 = nn.LayerNorm(d_model)

        # Cross-track attention (optional)
        if use_cross_track:
            self.cross_attn = CrossTrackAttention(d_model, n_heads, dropout)
            self.ln_cross = nn.LayerNorm(d_model)

        # Feed-forward
        self.ff = FeedForward(d_model, dropout=dropout)
        self.ln2 = nn.LayerNorm(d_model)

        self.dropout = nn.Dropout(dropout)

    def forward(
        self,
        x: torch.Tensor,
        mask: torch.Tensor = None,
        cross_track_mask: torch.Tensor = None,
        past_kv: tuple | None = None,
        use_cache: bool = False,
        cache_pos: int | None = None,
    ):
        """
        Forward pass.

        Args:
            x: (batch, seq_len, d_model) input
            mask: Causal mask for self-attention (optional, uses is_causal=True by default)
            cross_track_mask: (batch, seq_len, seq_len) mask for cross-track attention
            past_kv: Cached (self_attn_kv, cross_attn_kv) or None
            use_cache: Whether to return updated cache
            cache_pos: Position in static KV cache buffer (None for dynamic cache)

        Returns:
            (batch, seq_len, d_model) output, or tuple of (output, cache) if use_cache
        """
        # Unpack past KV for each sub-attention
        self_attn_past = None
        cross_attn_past = None
        if past_kv is not None:
            self_attn_past, cross_attn_past = past_kv

        # Self-attention with pre-norm
        if use_cache:
            sa_out, self_attn_present = self.self_attn(
                self.ln1(x), mask, past_kv=self_attn_past, use_cache=True,
                cache_pos=cache_pos)
        else:
            sa_out = self.self_attn(self.ln1(x), mask)
            self_attn_present = None
        x = x + self.dropout(sa_out)

        # Cross-track attention (if enabled and mask provided)
        cross_attn_present = None
        if self.use_cross_track and cross_track_mask is not None:
            if use_cache:
                ca_out, cross_attn_present = self.cross_attn(
                    self.ln_cross(x), cross_track_mask,
                    past_kv=cross_attn_past, use_cache=True,
                    cache_pos=cache_pos)
            else:
                ca_out = self.cross_attn(self.ln_cross(x), cross_track_mask)
            x = x + self.dropout(ca_out)

        # Feed-forward with pre-norm
        x = x + self.dropout(self.ff(self.ln2(x)))

        if use_cache:
            return x, (self_attn_present, cross_attn_present)
        return x


class MultiTrackMusicTransformer(nn.Module):
    """
    Multi-track music transformer with cross-track attention.

    Extends MusicTransformer with:
    - Track embeddings to identify which track each token belongs to
    - Cross-track attention for inter-track coherence
    """

    def __init__(
        self,
        vocab_size: int,
        d_model: int = 512,
        n_heads: int = 8,
        n_layers: int = 12,
        max_seq_len: int = 16384,
        max_tracks: int = 16,
        dropout: float = 0.1,
        cross_track_layers: list[int] = None,
    ):
        """
        Initialize multi-track transformer.

        Args:
            vocab_size: Size of token vocabulary
            d_model: Model dimension
            n_heads: Number of attention heads
            n_layers: Number of transformer layers
            max_seq_len: Maximum sequence length
            max_tracks: Maximum number of tracks to support
            dropout: Dropout rate
            cross_track_layers: Which layers should have cross-track attention
                               (default: every 3rd layer starting from layer 3)
        """
        super().__init__()

        # Store config
        self.vocab_size = vocab_size
        self.d_model = d_model
        self.n_heads = n_heads
        self.n_layers = n_layers
        self.max_seq_len = max_seq_len
        self.max_tracks = max_tracks

        # Default: cross-track attention on layers 3, 6, 9, 12, etc.
        if cross_track_layers is None:
            cross_track_layers = [i for i in range(3, n_layers + 1, 3)]
        self.cross_track_layers = set(cross_track_layers)

        # Token and position embeddings
        self.token_emb = nn.Embedding(vocab_size, d_model)
        self.pos_enc = PositionalEncoding(d_model, max_seq_len, dropout)

        # Track embedding
        self.track_emb = TrackEmbedding(max_tracks, d_model)

        # Transformer blocks
        self.blocks = nn.ModuleList([
            MultiTrackTransformerBlock(
                d_model,
                n_heads,
                dropout,
                use_cross_track=(i + 1) in self.cross_track_layers,
            )
            for i in range(n_layers)
        ])

        # Output projection
        self.ln_final = nn.LayerNorm(d_model)
        self.head = nn.Linear(d_model, vocab_size)

        # Initialize weights
        self.apply(self._init_weights)

        # Depth-scaled init: scale residual output projections by 1/sqrt(2*n_layers)
        # to prevent residual stream variance from growing with depth (GPT-2 trick)
        residual_scale = 1.0 / math.sqrt(2 * n_layers)
        for block in self.blocks:
            block.self_attn.out_proj.weight.data *= residual_scale
            block.ff.net[3].weight.data *= residual_scale
            if hasattr(block, 'cross_attn'):
                block.cross_attn.out_proj.weight.data *= residual_scale

    def _init_weights(self, module):
        if isinstance(module, nn.Linear):
            torch.nn.init.normal_(module.weight, mean=0.0, std=0.02)
            if module.bias is not None:
                torch.nn.init.zeros_(module.bias)
        elif isinstance(module, nn.Embedding):
            torch.nn.init.normal_(module.weight, mean=0.0, std=0.02)

    def forward(
        self,
        x: torch.Tensor,
        track_ids: torch.Tensor = None,
        cross_track_mask: torch.Tensor = None,
        past_kv: list | None = None,
        use_cache: bool = False,
        cache_pos: int | None = None,
    ):
        """
        Forward pass.

        Args:
            x: Token indices, shape (batch_size, seq_len)
            track_ids: Track ID for each token, shape (batch_size, seq_len)
                      Values from -1 (non-track) to max_tracks-1
            cross_track_mask: Pre-computed cross-track attention mask
                             Shape (batch_size, seq_len, seq_len) or (batch, 1, total_len) for cached step
            past_kv: List of cached (self_attn_kv, cross_attn_kv) per layer
            use_cache: Whether to return updated KV cache
            cache_pos: Position in static KV cache buffer (None for dynamic cache)

        Returns:
            Logits over vocabulary, shape (batch_size, seq_len, vocab_size),
            or tuple of (logits, kv_cache) if use_cache
        """
        # Token embeddings
        if past_kv is not None:
            # Cached: use cache_pos if static cache, otherwise infer from cache size
            pos_offset = cache_pos if cache_pos is not None else past_kv[0][0][0].size(2)
            h = self.token_emb(x)
            h = h + self.pos_enc.pe[:, pos_offset:pos_offset + x.size(1)]
        else:
            h = self.token_emb(x)
            h = self.pos_enc(h)

        # Add track embedding if provided
        if track_ids is not None:
            h = h + self.track_emb(track_ids)

        present_kv_list = []

        # Transformer blocks
        for i, block in enumerate(self.blocks):
            layer_past = past_kv[i] if past_kv is not None else None
            if use_cache:
                h, present = block(h, cross_track_mask=cross_track_mask,
                                   past_kv=layer_past, use_cache=True,
                                   cache_pos=cache_pos)
                present_kv_list.append(present)
            else:
                h = block(h, cross_track_mask=cross_track_mask)

        # Output
        h = self.ln_final(h)
        logits = self.head(h)

        if use_cache:
            return logits, present_kv_list
        return logits

    def _compute_bar_positions(self, token_ids: torch.Tensor, track_ids: torch.Tensor, vocab: dict) -> torch.Tensor:
        """Compute bar positions from actual Bar tokens in the generated sequence.

        Uses vectorized cumsum + cummax to avoid Python loops.
        Bar counter increments at BAR_START and resets to 0 at TRACK_START.
        """
        bar_start_id = vocab.get("BAR_START")
        track_start_id = vocab.get("TRACK_START")
        if bar_start_id is None or track_start_id is None:
            warnings.warn(
                f"BAR_START or TRACK_START not in vocab "
                f"(BAR_START={bar_start_id}, TRACK_START={track_start_id}). "
                f"Bar positions will be all zeros — cross-track attention will be degraded.",
                stacklevel=2,
            )
            return torch.zeros_like(token_ids)

        is_bar_start = (token_ids == bar_start_id).long()
        is_track_start = (token_ids == track_start_id)
        bar_cumsum = torch.cumsum(is_bar_start, dim=1)
        # At each TRACK_START, record cumulative bar count; cummax propagates forward
        track_start_vals = torch.where(is_track_start, bar_cumsum, torch.zeros_like(bar_cumsum))
        offsets = torch.cummax(track_start_vals, dim=1)[0]
        return bar_cumsum - offsets

    @torch.inference_mode()
    def generate(
        self,
        prompt: torch.Tensor,
        track_ids: torch.Tensor = None,
        max_new_tokens: int = 256,
        temperature: float = 1.0,
        top_k: int = 50,
        top_p: float = 0.95,
        vocab_size: int = None,
        track_id_for_new_tokens: int = 0,
        suppress_tokens: list[int] = None,
        stop_tokens: list[int] = None,
        repetition_penalty: float = 1.0,
        n_prefix_tokens: int = 0,
        vocab: dict = None,
        use_cache: bool = True,
        on_progress=None,
    ) -> torch.Tensor:
        """
        Generate new tokens autoregressively.

        Args:
            prompt: Starting tokens, shape (1, prompt_len)
            track_ids: Track IDs for prompt tokens, shape (1, prompt_len)
            max_new_tokens: Number of tokens to generate
            temperature: Sampling temperature
            top_k: Keep only top k tokens for sampling
            top_p: Nucleus sampling threshold
            vocab_size: Constrain generation to this vocabulary size
            track_id_for_new_tokens: Track ID to assign to generated tokens
            suppress_tokens: List of token IDs to suppress (e.g. EOS to prevent early stopping)
            stop_tokens: List of token IDs that cause early stopping when generated.
                The stop token IS included in the output.
            repetition_penalty: Penalize repeated tokens (1.0 = disabled, >1.0 = less repetition)
            n_prefix_tokens: Number of conditioning tokens (tags + BOS) to always keep
                at the front when the sliding window truncates the sequence
            vocab: Tokenizer vocab dict (token_name -> id) for computing bar positions
            use_cache: Use KV cache for faster generation (default: True)
            on_progress: Optional callback(step, max_new_tokens) called periodically

        Returns:
            Generated sequence including prompt
        """
        self.eval()

        from .multitrack_utils import (
            build_cross_track_attention_mask_efficient,
            build_cross_track_mask_row,
            compute_track_ids as _compute_track_ids,
        )

        logger.debug(
            f"multitrack generate: prompt={prompt.shape}, max_new_tokens={max_new_tokens}, "
            f"temp={temperature}, top_k={top_k}, top_p={top_p}, "
            f"rep_penalty={repetition_penalty}, track_id={track_id_for_new_tokens}, "
            f"use_cache={use_cache}, max_seq_len={self.max_seq_len}, device={prompt.device}"
        )

        t_start = time.monotonic()
        cache_invalidations = 0
        tokens_generated = 0

        # Initialize track_ids if not provided
        if track_ids is None:
            track_ids = torch.zeros_like(prompt)

        stop_token_set = set(stop_tokens) if stop_tokens else set()
        _stop_tokens_tensor = torch.tensor(list(stop_token_set), device=prompt.device) if stop_token_set else None
        progress_interval = max(1, max_new_tokens // 20)  # ~5% increments

        if not use_cache:
            # Original non-cached path
            for step in range(max_new_tokens):
                if prompt.size(1) > self.max_seq_len:
                    if n_prefix_tokens > 0:
                        prefix = prompt[:, :n_prefix_tokens]
                        tail = prompt[:, -(self.max_seq_len - n_prefix_tokens):]
                        x = torch.cat([prefix, tail], dim=1)
                        t_prefix = track_ids[:, :n_prefix_tokens]
                        t_tail = track_ids[:, -(self.max_seq_len - n_prefix_tokens):]
                        t_ids = torch.cat([t_prefix, t_tail], dim=1)
                    else:
                        x = prompt[:, -self.max_seq_len:]
                        t_ids = track_ids[:, -self.max_seq_len:]
                    if step == 0:
                        logger.debug(f"multitrack generate: sliding window active, input truncated to {x.shape[1]} tokens")
                else:
                    x = prompt
                    t_ids = track_ids
                bar_positions = self._compute_bar_positions(x, t_ids, vocab)
                cross_track_mask = build_cross_track_attention_mask_efficient(t_ids, bar_positions)
                logits = self(x, track_ids=t_ids, cross_track_mask=cross_track_mask)[:, -1, :] / temperature
                next_token = _apply_sampling_filters(
                    logits, vocab_size, suppress_tokens, top_k, top_p,
                    repetition_penalty=repetition_penalty,
                    past_tokens=prompt,
                )
                prompt = torch.cat([prompt, next_token], dim=1)
                new_track_id = torch.full_like(next_token, track_id_for_new_tokens)
                track_ids = torch.cat([track_ids, new_track_id], dim=1)
                tokens_generated += 1

                if on_progress and step % progress_interval == 0:
                    on_progress(step + 1, max_new_tokens)

                if _stop_tokens_tensor is not None and (next_token.squeeze() == _stop_tokens_tensor).any().item():
                    logger.debug(f"multitrack generate: early stop at step {step}, stop token encountered")
                    break

            elapsed = time.monotonic() - t_start
            logger.debug(
                f"multitrack generate done (no-cache): {tokens_generated} tokens in {elapsed:.1f}s "
                f"({tokens_generated / elapsed:.1f} tok/s), final seq_len={prompt.shape[1]}"
            )
            return prompt

        # === Cached generation ===

        # Only use BAR_START for bar counting (matches _compute_bar_positions
        # and multitrack_utils.compute_time_positions)
        bar_start_id = vocab.get("BAR_START") if vocab else None
        track_start_id = vocab.get("TRACK_START") if vocab else None
        if vocab and (bar_start_id is None or track_start_id is None):
            warnings.warn(
                f"BAR_START or TRACK_START not in vocab "
                f"(BAR_START={bar_start_id}, TRACK_START={track_start_id}). "
                f"Bar positions will be incorrect during generation.",
                stacklevel=2,
            )

        # Sentinel values for GPU-side comparisons (-1 never matches a real token)
        _track_start_id = track_start_id if track_start_id is not None else -1
        _bar_start_id = bar_start_id if bar_start_id is not None else -1

        # Prefill: truncate if prompt exceeds max_seq_len (sliding window)
        prefill_prompt = prompt
        prefill_track_ids = track_ids
        if prompt.size(1) > self.max_seq_len:
            if n_prefix_tokens > 0:
                prefix = prompt[:, :n_prefix_tokens]
                tail = prompt[:, -(self.max_seq_len - n_prefix_tokens):]
                prefill_prompt = torch.cat([prefix, tail], dim=1)
                t_prefix = track_ids[:, :n_prefix_tokens]
                t_tail = track_ids[:, -(self.max_seq_len - n_prefix_tokens):]
                prefill_track_ids = torch.cat([t_prefix, t_tail], dim=1)
            else:
                prefill_prompt = prompt[:, -self.max_seq_len:]
                prefill_track_ids = track_ids[:, -self.max_seq_len:]
            logger.debug(
                f"multitrack generate: prefill truncated from {prompt.size(1)} to "
                f"{prefill_prompt.size(1)} tokens (max_seq_len={self.max_seq_len})"
            )

        # Compute bar_positions and full cross-track mask
        bar_positions = self._compute_bar_positions(prefill_prompt, prefill_track_ids, vocab)
        cross_track_mask = build_cross_track_attention_mask_efficient(prefill_track_ids, bar_positions)
        logits, past_kv = self(prefill_prompt, track_ids=prefill_track_ids,
                               cross_track_mask=cross_track_mask, use_cache=True)
        logger.debug(
            f"multitrack generate: prefill complete, cache_len={past_kv[0][0][0].size(2)}, "
            f"bar_range=[{bar_positions.min().item()}, {bar_positions.max().item()}]"
        )

        # Convert to static KV cache (pre-allocated buffers, eliminates per-step allocations)
        prefill_len = prefill_prompt.size(1)
        cache_pos = prefill_len
        static_kv = _make_static_kv_multitrack(past_kv, self.max_seq_len)

        # Pre-allocate output buffer to avoid O(n²) copies from torch.cat
        prompt_len = prompt.size(1)
        total_len = prompt_len + max_new_tokens
        token_buf = torch.empty(1, total_len, dtype=prompt.dtype, device=prompt.device)
        token_buf[:, :prompt_len] = prompt
        cursor = prompt_len

        # Pre-allocate cache-aligned buffers for mask computation
        cache_buf_size = prefill_len + max_new_tokens
        cache_track_ids = torch.empty(1, cache_buf_size, dtype=track_ids.dtype, device=prompt.device)
        cache_track_ids[:, :prefill_len] = prefill_track_ids
        cache_bar_pos = torch.zeros(1, cache_buf_size, dtype=torch.long, device=prompt.device)
        cache_bar_pos[:, :prefill_len] = bar_positions

        # Pre-allocate reusable tensor for track ID of new tokens
        new_track_id_tensor = torch.full((1, 1), track_id_for_new_tokens,
                                         dtype=track_ids.dtype, device=prompt.device)

        for step in range(max_new_tokens):
            # Sample from last position
            last_logits = logits[:, -1, :] / temperature
            next_token = _apply_sampling_filters(
                last_logits, vocab_size, suppress_tokens, top_k, top_p,
                repetition_penalty=repetition_penalty,
                past_tokens=token_buf[:, :cursor],
            )

            # Write to pre-allocated buffers (no torch.cat)
            token_buf[:, cursor:cursor + 1] = next_token
            cursor += 1
            tokens_generated += 1

            # Update cache-aligned buffers
            cache_track_ids[0, cache_pos] = track_id_for_new_tokens

            # GPU-side bar position computation (avoids per-step CPU sync)
            prev_bar = cache_bar_pos[:, cache_pos - 1:cache_pos]
            is_track_start = (next_token == _track_start_id)
            is_bar_start = (next_token == _bar_start_id)
            new_bar = torch.where(is_track_start,
                                  torch.zeros_like(prev_bar),
                                  torch.where(is_bar_start, prev_bar + 1, prev_bar))
            cache_bar_pos[:, cache_pos:cache_pos + 1] = new_bar

            # Log sampling diagnostics periodically (syncs only when logging)
            if logger.isEnabledFor(logging.DEBUG) and (step % 50 == 0 or step == max_new_tokens - 1):
                token_val = next_token.item()
                bar_val = new_bar.item()
                probs = torch.softmax(last_logits, dim=-1)
                top5_probs, top5_ids = probs.topk(5, dim=-1)
                entropy = -(probs * (probs + 1e-10).log()).sum(dim=-1).item()
                logger.debug(
                    f"  step {step}/{max_new_tokens}: "
                    f"token={token_val}, bar={bar_val}, "
                    f"top5_probs=[{', '.join(f'{p:.3f}' for p in top5_probs[0].tolist())}], "
                    f"entropy={entropy:.2f}, seq_len={cursor}"
                )

            if on_progress and step % progress_interval == 0:
                on_progress(step + 1, max_new_tokens)

            # Early stopping (GPU comparison, single boolean sync)
            if _stop_tokens_tensor is not None and (next_token.squeeze() == _stop_tokens_tensor).any().item():
                logger.debug(f"multitrack generate: early stop at step {step}, stop token encountered")
                break

            # Check if cache exceeds max_seq_len
            if cache_pos + 1 > self.max_seq_len:
                cache_invalidations += 1
                # Truncate to 75% of max_seq_len to leave headroom before next eviction
                keep_len = self.max_seq_len * 3 // 4
                all_tokens = token_buf[:, :cursor]
                if n_prefix_tokens > 0:
                    suffix_len = keep_len - n_prefix_tokens
                    x = torch.cat([all_tokens[:, :n_prefix_tokens], all_tokens[:, -suffix_len:]], dim=1)
                else:
                    x = all_tokens[:, -keep_len:]
                # Recompute track IDs and bar positions for compacted sequence
                t_ids_list = _compute_track_ids(x[0].tolist(), vocab)
                t_ids = torch.tensor([t_ids_list], dtype=torch.long, device=x.device)
                bp = self._compute_bar_positions(x, t_ids, vocab)
                cross_track_mask = build_cross_track_attention_mask_efficient(t_ids, bp)
                logits, past_kv = self(x, track_ids=t_ids,
                                       cross_track_mask=cross_track_mask, use_cache=True)
                cache_pos = x.size(1)
                cache_track_ids[:, :cache_pos] = t_ids
                cache_bar_pos[:, :cache_pos] = bp
                static_kv = _make_static_kv_multitrack(past_kv, self.max_seq_len)
                logger.debug(
                    f"  step {step}: cache invalidated (pos={cache_pos} > max={self.max_seq_len}), "
                    f"re-prefilled {x.shape[1]} tokens"
                )
            else:
                # Incremental step: compute single mask row (static cache, no allocations)
                mask_row = build_cross_track_mask_row(
                    cache_track_ids[:, :cache_pos + 1],
                    cache_bar_pos[:, :cache_pos + 1],
                )
                logits, _ = self(
                    next_token,
                    track_ids=new_track_id_tensor,
                    cross_track_mask=mask_row,
                    past_kv=static_kv,
                    use_cache=True,
                    cache_pos=cache_pos,
                )
                cache_pos += 1

        elapsed = time.monotonic() - t_start
        logger.debug(
            f"multitrack generate done: {tokens_generated} tokens in {elapsed:.1f}s "
            f"({tokens_generated / elapsed:.1f} tok/s), "
            f"final seq_len={cursor}, cache_invalidations={cache_invalidations}"
        )
        return token_buf[:, :cursor]

    def load_single_track_weights(self, checkpoint_path: str, device: torch.device):
        """
        Load weights from a single-track MusicTransformer checkpoint.

        Compatible layers are transferred, new layers keep random initialization.

        Args:
            checkpoint_path: Path to single-track model checkpoint
            device: Device to load weights to
        """
        checkpoint = torch.load(checkpoint_path, map_location=device, weights_only=False)
        legacy_state = checkpoint.get("model_state_dict", checkpoint)

        # Handle state dict from torch.compile() wrapped models
        if any(k.startswith("_orig_mod.") for k in legacy_state.keys()):
            legacy_state = {k.replace("_orig_mod.", ""): v for k, v in legacy_state.items()}

        current_state = self.state_dict()
        loaded_keys = []
        skipped_keys = []

        for key, value in legacy_state.items():
            if key in current_state:
                if current_state[key].shape == value.shape:
                    current_state[key] = value
                    loaded_keys.append(key)
                else:
                    skipped_keys.append(f"{key} (shape mismatch)")
            else:
                skipped_keys.append(f"{key} (not found)")

        self.load_state_dict(current_state)

        print(f"Loaded {len(loaded_keys)} layers from single-track checkpoint")
        if skipped_keys:
            print(f"Skipped {len(skipped_keys)} layers (new or incompatible)")
