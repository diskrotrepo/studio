"""
Sampling Filters

Token sampling utilities for autoregressive generation.
"""

import logging
import torch

logger = logging.getLogger(__name__)


def _apply_sampling_filters(
    logits: torch.Tensor,
    vocab_size: int | None = None,
    suppress_tokens: list[int] | None = None,
    top_k: int = 0,
    top_p: float = 1.0,
    repetition_penalty: float = 1.0,
    past_tokens: torch.Tensor | None = None,
    repetition_window: int = 256,
) -> torch.Tensor:
    """
    Apply vocabulary masking, token suppression, repetition penalty, top-k,
    and top-p filtering to logits, then sample a single token.

    Args:
        logits: Scaled logits for the last position, shape (batch, vocab)
        vocab_size: Mask tokens beyond this index
        suppress_tokens: Token IDs to force to -inf
        top_k: Keep only top-k tokens (0 to disable)
        top_p: Nucleus sampling threshold (1.0 to disable)
        repetition_penalty: Penalize previously generated tokens (1.0 = disabled, >1.0 = less repetition)
        past_tokens: Previously generated token IDs, shape (batch, seq_len)

    Returns:
        Sampled token tensor, shape (batch, 1)
    """
    if vocab_size is not None and vocab_size < logits.size(-1):
        logits[:, vocab_size:] = float("-inf")

    if suppress_tokens:
        vocab_width = logits.size(-1)
        for token_id in suppress_tokens:
            if 0 <= token_id < vocab_width:
                logits[:, token_id] = float("-inf")

    if repetition_penalty != 1.0 and past_tokens is not None:
        # Only look at recent tokens to limit gather/scatter cost
        if repetition_window > 0 and past_tokens.size(1) > repetition_window:
            past_tokens = past_tokens[:, -repetition_window:]
        # Gather logits for tokens that have appeared in the past
        score = torch.gather(logits, 1, past_tokens)
        # Apply penalty: divide positive logits, multiply negative logits
        score = torch.where(score > 0, score / repetition_penalty, score * repetition_penalty)
        logits.scatter_(1, past_tokens, score)

    if top_k > 0:
        top_k = min(top_k, logits.size(-1))
        indices_to_remove = logits < torch.topk(logits, top_k)[0][:, -1, None]
        logits[indices_to_remove] = float("-inf")

    if top_p < 1.0:
        sorted_logits, sorted_indices = torch.sort(logits, descending=True)
        cumulative_probs = torch.cumsum(torch.softmax(sorted_logits, dim=-1), dim=-1)

        sorted_indices_to_remove = cumulative_probs > top_p
        sorted_indices_to_remove[:, 1:] = sorted_indices_to_remove[:, :-1].clone()
        sorted_indices_to_remove[:, 0] = 0

        indices_to_remove = sorted_indices_to_remove.scatter(
            1, sorted_indices, sorted_indices_to_remove
        )
        logits[indices_to_remove] = float("-inf")

    probs = torch.softmax(logits, dim=-1)

    # Warn on degenerate distributions (all filtered, or single token dominates)
    if logger.isEnabledFor(logging.DEBUG):
        finite_mask = logits > float("-inf")
        effective_vocab = finite_mask.sum(dim=-1).item()
        top1_prob = probs.max(dim=-1).values.item()
        if effective_vocab <= 1:
            logger.debug(
                f"sampling: degenerate distribution, effective_vocab={effective_vocab}"
            )
        elif top1_prob > 0.99:
            logger.debug(
                f"sampling: near-deterministic, top1_prob={top1_prob:.4f}, "
                f"effective_vocab={effective_vocab}"
            )

    return torch.multinomial(probs, num_samples=1)
