"""
Single-Track Music Transformer

GPT-style transformer for autoregressive music generation.
"""

import logging
import math
import time
import torch
import torch.nn as nn

from .layers import PositionalEncoding, TransformerBlock
from .sampling import _apply_sampling_filters

logger = logging.getLogger(__name__)


def _make_static_kv(past_kv, max_len):
    """Convert dynamic KV cache (list of (K,V) tuples) to pre-allocated static buffers."""
    static = []
    for k, v in past_kv:
        k_buf = torch.zeros(k.shape[0], k.shape[1], max_len, k.shape[3],
                            dtype=k.dtype, device=k.device)
        v_buf = torch.zeros_like(k_buf)
        k_buf[:, :, :k.size(2)] = k
        v_buf[:, :, :v.size(2)] = v
        static.append([k_buf, v_buf])
    return static


class MusicTransformer(nn.Module):
    """
    GPT-style transformer for music generation.

    Takes token sequences and predicts the next token at each position.
    """

    def __init__(
        self,
        vocab_size: int,
        d_model: int = 256,
        n_heads: int = 8,
        n_layers: int = 6,
        max_seq_len: int = 512,
        dropout: float = 0.1,
    ):
        super().__init__()

        # Store config for saving/loading
        self.vocab_size = vocab_size
        self.d_model = d_model
        self.n_heads = n_heads
        self.n_layers = n_layers
        self.max_seq_len = max_seq_len

        # Token and position embeddings
        self.token_emb = nn.Embedding(vocab_size, d_model)
        self.pos_enc = PositionalEncoding(d_model, max_seq_len, dropout)

        # Transformer blocks
        self.blocks = nn.ModuleList([
            TransformerBlock(d_model, n_heads, dropout)
            for _ in range(n_layers)
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
            block.attn.out_proj.weight.data *= residual_scale
            block.ff.net[3].weight.data *= residual_scale

    def _init_weights(self, module):
        if isinstance(module, nn.Linear):
            torch.nn.init.normal_(module.weight, mean=0.0, std=0.02)
            if module.bias is not None:
                torch.nn.init.zeros_(module.bias)
        elif isinstance(module, nn.Embedding):
            torch.nn.init.normal_(module.weight, mean=0.0, std=0.02)

    def forward(self, x: torch.Tensor,
                past_kv: list | None = None,
                use_cache: bool = False,
                cache_pos: int | None = None):
        """
        Forward pass.

        Args:
            x: Token indices, shape (batch_size, seq_len)
            past_kv: List of cached (K, V) tuples per layer
            use_cache: Whether to return updated KV cache
            cache_pos: Position in static KV cache buffer (None for dynamic cache)

        Returns:
            Logits over vocabulary, shape (batch_size, seq_len, vocab_size),
            or tuple of (logits, kv_cache) if use_cache
        """
        # Embeddings
        if past_kv is not None:
            # Cached: use cache_pos if static cache, otherwise infer from cache size
            pos_offset = cache_pos if cache_pos is not None else past_kv[0][0].size(2)
            h = self.token_emb(x)
            h = h + self.pos_enc.pe[:, pos_offset:pos_offset + x.size(1)]
        else:
            h = self.token_emb(x)
            h = self.pos_enc(h)

        present_kv_list = []

        # Transformer blocks
        for i, block in enumerate(self.blocks):
            layer_past = past_kv[i] if past_kv is not None else None
            if use_cache:
                h, present = block(h, past_kv=layer_past, use_cache=True,
                                   cache_pos=cache_pos)
                present_kv_list.append(present)
            else:
                h = block(h)

        # Output
        h = self.ln_final(h)
        logits = self.head(h)

        if use_cache:
            return logits, present_kv_list
        return logits

    @torch.inference_mode()
    def generate(
        self,
        prompt: torch.Tensor,
        max_new_tokens: int = 256,
        temperature: float = 1.0,
        top_k: int = 50,
        top_p: float = 0.95,
        vocab_size: int = None,
        suppress_tokens: list[int] = None,
        repetition_penalty: float = 1.0,
        n_prefix_tokens: int = 0,
        use_cache: bool = True,
        on_progress=None,
        **kwargs,
    ) -> torch.Tensor:
        """
        Generate new tokens autoregressively.

        Args:
            prompt: Starting tokens, shape (1, prompt_len)
            max_new_tokens: Number of tokens to generate
            temperature: Sampling temperature (higher = more random)
            top_k: Keep only top k tokens for sampling
            top_p: Nucleus sampling threshold
            vocab_size: Constrain generation to this vocabulary size (if smaller than model's vocab)
            suppress_tokens: List of token IDs to suppress (e.g. EOS to prevent early stopping)
            repetition_penalty: Penalize repeated tokens (1.0 = disabled, >1.0 = less repetition)
            n_prefix_tokens: Number of conditioning tokens (tags + BOS) to always keep
                at the front when the sliding window truncates the sequence
            use_cache: Use KV cache for faster generation (default: True)
            on_progress: Optional callback(step, max_new_tokens) called periodically

        Returns:
            Generated sequence including prompt
        """
        self.eval()

        logger.debug(
            f"generate: prompt={prompt.shape}, max_new_tokens={max_new_tokens}, "
            f"temp={temperature}, top_k={top_k}, top_p={top_p}, "
            f"rep_penalty={repetition_penalty}, use_cache={use_cache}, "
            f"max_seq_len={self.max_seq_len}, device={prompt.device}"
        )

        t_start = time.monotonic()
        cache_invalidations = 0

        progress_interval = max(1, max_new_tokens // 20)  # ~5% increments

        if not use_cache:
            # Original non-cached path
            for step in range(max_new_tokens):
                if prompt.size(1) > self.max_seq_len:
                    if n_prefix_tokens > 0:
                        prefix = prompt[:, :n_prefix_tokens]
                        tail = prompt[:, -(self.max_seq_len - n_prefix_tokens):]
                        x = torch.cat([prefix, tail], dim=1)
                    else:
                        x = prompt[:, -self.max_seq_len:]
                    if step == 0:
                        logger.debug(f"generate: sliding window active, input truncated to {x.shape[1]} tokens")
                else:
                    x = prompt
                logits = self(x)[:, -1, :] / temperature
                next_token = _apply_sampling_filters(
                    logits, vocab_size, suppress_tokens, top_k, top_p,
                    repetition_penalty=repetition_penalty,
                    past_tokens=prompt,
                )
                prompt = torch.cat([prompt, next_token], dim=1)

                if on_progress and step % progress_interval == 0:
                    on_progress(step + 1, max_new_tokens)

            elapsed = time.monotonic() - t_start
            logger.debug(
                f"generate done (no-cache): {max_new_tokens} tokens in {elapsed:.1f}s "
                f"({max_new_tokens / elapsed:.1f} tok/s), final seq_len={prompt.shape[1]}"
            )
            return prompt

        # === Cached generation ===
        # Pre-allocate output buffer to avoid O(n²) copies from torch.cat
        prompt_len = prompt.size(1)
        total_len = prompt_len + max_new_tokens
        token_buf = torch.empty(1, total_len, dtype=prompt.dtype, device=prompt.device)
        token_buf[:, :prompt_len] = prompt
        cursor = prompt_len

        # Prefill: process entire prompt
        logits, past_kv = self(prompt, use_cache=True)
        logger.debug(f"generate: prefill complete, cache_len={past_kv[0][0].size(2)}")

        # Convert to static KV cache (pre-allocated buffers, eliminates per-step allocations)
        cache_pos = prompt_len
        static_kv = _make_static_kv(past_kv, self.max_seq_len)

        for step in range(max_new_tokens):
            # Sample from last position
            last_logits = logits[:, -1, :] / temperature
            next_token = _apply_sampling_filters(
                last_logits, vocab_size, suppress_tokens, top_k, top_p,
                repetition_penalty=repetition_penalty,
                past_tokens=token_buf[:, :cursor],
            )
            token_buf[:, cursor:cursor + 1] = next_token
            cursor += 1

            # Log sampling diagnostics periodically
            if logger.isEnabledFor(logging.DEBUG) and (step % 50 == 0 or step == max_new_tokens - 1):
                probs = torch.softmax(last_logits, dim=-1)
                top5_probs, top5_ids = probs.topk(5, dim=-1)
                entropy = -(probs * (probs + 1e-10).log()).sum(dim=-1).item()
                logger.debug(
                    f"  step {step}/{max_new_tokens}: "
                    f"token={next_token.item()}, "
                    f"top5_probs=[{', '.join(f'{p:.3f}' for p in top5_probs[0].tolist())}], "
                    f"entropy={entropy:.2f}, seq_len={cursor}"
                )

            if on_progress and step % progress_interval == 0:
                on_progress(step + 1, max_new_tokens)

            # Check if cache exceeds max_seq_len
            if cache_pos + 1 > self.max_seq_len:
                cache_invalidations += 1
                # Truncate to 75% of max_seq_len to leave headroom before next eviction
                keep_len = self.max_seq_len * 3 // 4
                all_tokens = token_buf[:, :cursor]
                if n_prefix_tokens > 0:
                    prefix = all_tokens[:, :n_prefix_tokens]
                    tail = all_tokens[:, -(keep_len - n_prefix_tokens):]
                    x = torch.cat([prefix, tail], dim=1)
                else:
                    x = all_tokens[:, -keep_len:]
                logits, past_kv = self(x, use_cache=True)
                cache_pos = x.size(1)
                static_kv = _make_static_kv(past_kv, self.max_seq_len)
                logger.debug(
                    f"  step {step}: cache invalidated (pos={cache_pos} > max={self.max_seq_len}), "
                    f"re-prefilled {x.shape[1]} tokens"
                )
            else:
                # Cached step: process only the new token (static cache, no allocations)
                logits, _ = self(next_token, past_kv=static_kv, use_cache=True,
                                 cache_pos=cache_pos)
                cache_pos += 1

        elapsed = time.monotonic() - t_start
        logger.debug(
            f"generate done: {max_new_tokens} tokens in {elapsed:.1f}s "
            f"({max_new_tokens / elapsed:.1f} tok/s), "
            f"final seq_len={cursor}, cache_invalidations={cache_invalidations}"
        )
        return token_buf[:, :cursor]
