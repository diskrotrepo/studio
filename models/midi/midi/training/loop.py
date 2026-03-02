"""Training loop and validation."""

import math
import torch
import torch.nn as nn
from tqdm import tqdm

from .distributed import is_main_process


def train_epoch(
    model,
    dataloader,
    optimizer,
    device,
    epoch,
    rank=0,
    grad_accum=1,
    is_multitrack=False,
    grad_clip_norm=1.0,
    scheduler=None,
    scaler=None,
    loss_csv_path=None,
):
    """
    Train for one epoch with gradient accumulation.

    Handles both single-track and multi-track modes.
    For multi-track, expects dataloader to return (x, y, track_ids, bar_positions) tuples.

    Returns:
        Tuple of (avg_loss, metrics_dict) where metrics_dict contains
        grad_norm_avg, grad_norm_max, non_pad_pct, and num_batches.
    """
    if is_multitrack:
        from ..model.multitrack_utils import build_cross_track_attention_mask_efficient

    model.train()
    total_loss = 0
    num_batches = 0
    grad_norms = []
    skipped_steps = 0
    total_non_pad = 0
    total_tokens = 0

    use_amp = device.type in ("cuda", "mps")
    amp_dtype = torch.float16 if device.type == "mps" else torch.bfloat16

    pbar = tqdm(dataloader, desc=f"Epoch {epoch}", disable=not is_main_process(rank))
    for batch_idx, batch in enumerate(pbar):
        if batch_idx == 0 and epoch == 1 and is_main_process(rank):
            tqdm.write("Compiling kernels (first batch will be slow)...")
            # Log first-batch token distribution for debugging
            if is_multitrack:
                sample_tokens = batch[0][0].tolist()  # x from first sample
            else:
                sample_tokens = batch[0][0].tolist()
            from collections import Counter
            token_counts = Counter(sample_tokens)
            tqdm.write(
                f"  First batch token stats: {len(set(sample_tokens))} unique, "
                f"range [{min(sample_tokens)}, {max(sample_tokens)}]"
            )
            tqdm.write(f"  Top 20 tokens: {token_counts.most_common(20)}")
        # Unpack batch based on mode
        if is_multitrack:
            x, y, track_ids, bar_positions = batch
            # Compute cross-track mask on CPU before GPU transfer
            cross_track_mask = build_cross_track_attention_mask_efficient(
                track_ids, bar_positions
            )
            x = x.to(device, non_blocking=True)
            y = y.to(device, non_blocking=True)
            track_ids = track_ids.to(device, non_blocking=True)
            bar_positions = bar_positions.to(device, non_blocking=True)
            cross_track_mask = cross_track_mask.to(device, non_blocking=True)
        else:
            x, y = batch
            x, y = x.to(device, non_blocking=True), y.to(device, non_blocking=True)
            track_ids, cross_track_mask = None, None

        # Track non-padding tokens (accumulate on GPU, sync once at epoch end)
        total_non_pad += (y != -100).sum()
        total_tokens += y.numel()

        # Mark step begin for CUDA Graphs (required with torch.compile max-autotune)
        torch.compiler.cudagraph_mark_step_begin()

        # Mixed precision forward pass
        with torch.autocast(device_type=device.type, dtype=amp_dtype, enabled=use_amp):
            if is_multitrack:
                logits = model(x, track_ids=track_ids, cross_track_mask=cross_track_mask)
            else:
                logits = model(x)
            loss = nn.functional.cross_entropy(
                logits.view(-1, logits.size(-1)), y.view(-1), ignore_index=-100
            )
            # Scale loss for gradient accumulation
            loss = loss / grad_accum

        # Backward pass (with GradScaler for float16 on MPS)
        if scaler is not None:
            scaler.scale(loss).backward()
        else:
            loss.backward()

        # Step optimizer every grad_accum batches
        if (batch_idx + 1) % grad_accum == 0 or (batch_idx + 1) == len(dataloader):
            if scaler is not None:
                scaler.unscale_(optimizer)
            grad_norm = torch.nn.utils.clip_grad_norm_(model.parameters(), grad_clip_norm)
            grad_norm_val = grad_norm.item() if isinstance(grad_norm, torch.Tensor) else grad_norm
            grad_norms.append(grad_norm_val)

            # Skip optimizer step if gradient norm is anomalous
            running_avg = sum(grad_norms) / len(grad_norms) if len(grad_norms) > 1 else grad_norm_val
            skip_step = (
                len(grad_norms) > 10
                and grad_norm_val > max(10.0 * running_avg, 100.0)
            )

            if skip_step:
                skipped_steps += 1
                if is_main_process(rank):
                    tqdm.write(
                        f"  [!] Skipping step {len(grad_norms)}: "
                        f"grad_norm={grad_norm_val:.1f} vs avg={running_avg:.2f} "
                        f"({skipped_steps} skipped so far)"
                    )
                optimizer.zero_grad(set_to_none=True)
                if scheduler is not None:
                    scheduler.step()
            elif scaler is not None:
                scaler.step(optimizer)
                scaler.update()
                if scheduler is not None:
                    scheduler.step()
                optimizer.zero_grad(set_to_none=True)
            else:
                optimizer.step()
                if scheduler is not None:
                    scheduler.step()
                optimizer.zero_grad(set_to_none=True)

        step_loss = loss.item() * grad_accum
        if not math.isfinite(step_loss):
            if is_main_process(rank):
                tqdm.write(
                    f"\n*** FATAL: Non-finite loss at epoch {epoch}, "
                    f"batch {batch_idx}: loss={step_loss} ***"
                )
                tqdm.write(f"  Last grad_norm: {grad_norms[-1] if grad_norms else 'N/A'}")
                tqdm.write(f"  x range: [{x.min().item()}, {x.max().item()}]")
                tqdm.write(f"  logits range: [{logits.min().item():.4f}, {logits.max().item():.4f}]")
            raise RuntimeError(
                f"Non-finite loss at epoch {epoch}, batch {batch_idx}: {step_loss}"
            )

        total_loss += step_loss
        num_batches += 1
        if is_main_process(rank):
            pbar.set_postfix({"loss": f"{step_loss:.4f}"})
            if loss_csv_path is not None:
                import csv
                grad_norm_str = f"{grad_norms[-1]:.4f}" if grad_norms else ""
                with open(loss_csv_path, "a", newline="") as f:
                    csv.writer(f).writerow([epoch, batch_idx, f"{step_loss:.6f}", grad_norm_str])

    # Compute metrics (single GPU sync for non-pad ratio)
    avg_loss = total_loss / num_batches
    non_pad_pct = (total_non_pad / total_tokens).item() * 100 if total_tokens > 0 else 0.0
    metrics = {
        "grad_norm_avg": sum(grad_norms) / len(grad_norms) if grad_norms else 0.0,
        "grad_norm_max": max(grad_norms) if grad_norms else 0.0,
        "non_pad_pct": non_pad_pct,
        "num_batches": num_batches,
        "skipped_steps": skipped_steps,
    }
    return avg_loss, metrics


def validate(model, dataloader, device, is_multitrack=False):
    """
    Evaluate on validation set.

    Handles both single-track and multi-track modes.
    """
    if is_multitrack:
        from ..model.multitrack_utils import build_cross_track_attention_mask_efficient

    model.eval()
    total_loss = 0

    use_amp = device.type in ("cuda", "mps")
    amp_dtype = torch.float16 if device.type == "mps" else torch.bfloat16

    with torch.inference_mode():
        for batch in dataloader:
            if is_multitrack:
                x, y, track_ids, bar_positions = batch
                # Compute cross-track mask on CPU before GPU transfer
                cross_track_mask = build_cross_track_attention_mask_efficient(
                    track_ids, bar_positions
                )
                x = x.to(device, non_blocking=True)
                y = y.to(device, non_blocking=True)
                track_ids = track_ids.to(device, non_blocking=True)
                bar_positions = bar_positions.to(device, non_blocking=True)
                cross_track_mask = cross_track_mask.to(device, non_blocking=True)
            else:
                x, y = batch
                x, y = x.to(device, non_blocking=True), y.to(device, non_blocking=True)
                track_ids, cross_track_mask = None, None

            with torch.autocast(
                device_type=device.type, dtype=amp_dtype, enabled=use_amp
            ):
                if is_multitrack:
                    logits = model(
                        x, track_ids=track_ids, cross_track_mask=cross_track_mask
                    )
                else:
                    logits = model(x)
                loss = nn.functional.cross_entropy(
                    logits.view(-1, logits.size(-1)), y.view(-1), ignore_index=-100
                )
            total_loss += loss.item()

    return total_loss / len(dataloader)
