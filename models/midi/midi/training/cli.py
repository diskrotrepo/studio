"""Training CLI and orchestration."""

import argparse
import logging
import os
import random
import sys
import time
import traceback
from datetime import datetime
from pathlib import Path

import torch
import torch.multiprocessing as mp
import torch.distributed as dist
from torch.nn.parallel import DistributedDataParallel as DDP
from torch.utils.data import DataLoader
from torch.utils.data.distributed import DistributedSampler
from torch.optim.lr_scheduler import OneCycleLR, CosineAnnealingLR, LambdaLR, SequentialLR

from .config import TrainingConfig, compute_model_dims
from .dataset import MIDIDataset, MultiTrackMIDIDataset
from .loop import train_epoch, validate
from .checkpoint import (
    save_checkpoint,
    save_lora_adapter,
    load_checkpoint,
    load_pretrained_checkpoint,
    peek_checkpoint_config,
    freeze_layers,
)
from .distributed import (
    setup_logging,
    setup_distributed,
    cleanup_distributed,
    is_main_process,
)
from .cache import load_token_cache
from ..model import (
    MusicTransformer,
    MultiTrackMusicTransformer,
    enable_lora,
    count_lora_parameters,
)
from ..tokenization import get_tokenizer


def main():
    # ===================
    # A100/CUDA Optimizations
    # ===================
    if torch.cuda.is_available():
        torch.backends.cuda.matmul.allow_tf32 = True
        torch.backends.cudnn.allow_tf32 = True
        torch.backends.cudnn.benchmark = True
        torch.backends.cuda.enable_flash_sdp(True)
        torch.backends.cuda.enable_mem_efficient_sdp(True)

    # Suppress verbose torch.compile autotune logs
    logging.getLogger("torch._inductor.autotune").setLevel(logging.WARNING)

    # ===================
    # Argument Parsing
    # ===================
    parser = argparse.ArgumentParser(description="Train MIDI music generation model")
    parser.add_argument(
        "--midi-dir",
        type=str,
        default="midi_files",
        help="Directory containing .mid files (default: midi_files)",
    )
    parser.add_argument(
        "--checkpoint-dir",
        type=str,
        default="checkpoints",
        help="Directory for saving checkpoints (default: checkpoints)",
    )
    parser.add_argument(
        "--load-from",
        type=str,
        default=None,
        help="Path to pre-trained checkpoint to fine-tune from",
    )
    parser.add_argument(
        "--finetune",
        action="store_true",
        help="Fine-tune mode: reset epoch counter and use fresh optimizer",
    )
    parser.add_argument(
        "--lr",
        type=float,
        default=None,
        help="Learning rate (default: 3e-4, recommended 3e-5 for fine-tuning)",
    )
    parser.add_argument(
        "--freeze-layers",
        type=int,
        default=0,
        help="Number of transformer layers to freeze from the bottom (default: 0)",
    )
    parser.add_argument(
        "--lora",
        action="store_true",
        help="Enable LoRA training (freezes base model, trains small adapter)",
    )
    parser.add_argument(
        "--lora-rank",
        type=int,
        default=8,
        help="LoRA rank - higher = more capacity but more params (default: 8)",
    )
    parser.add_argument(
        "--lora-alpha",
        type=float,
        default=16.0,
        help="LoRA alpha scaling factor (default: 16.0)",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=None,
        help="Per-GPU batch size (default: 12 for A100 40GB, adjust based on GPU memory)",
    )
    parser.add_argument(
        "--grad-accum",
        type=int,
        default=None,
        help="Gradient accumulation steps (default: 4)",
    )
    parser.add_argument(
        "--config",
        type=str,
        default=None,
        help="Path to JSON config file (e.g., configs/m4_max_128gb.json). "
             "CLI args like --batch-size, --lr still override config file values.",
    )
    parser.add_argument(
        "--no-warmup",
        action="store_true",
        help="Skip LR warmup (useful when resuming a partially-trained model)",
    )
    parser.add_argument(
        "--epochs",
        type=int,
        default=None,
        help="Number of training epochs (overrides config value)",
    )
    parser.add_argument(
        "--max-files",
        type=int,
        default=None,
        help="Limit number of sequences to train on (for smoke-testing)",
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Enable DEBUG-level logging (model shapes, token stats, gradient details)",
    )
    args = parser.parse_args()

    # Validate LoRA arguments
    if args.lora and not args.load_from:
        parser.error("--lora requires --load-from to specify the base model")

    # Set spawn method for CUDA compatibility with DataLoader workers
    if mp.get_start_method(allow_none=True) is None:
        mp.set_start_method("spawn")

    # ===================
    # Configuration
    # ===================
    AUTO_CONFIG_PATH = "configs/auto.json"
    if args.config:
        config = TrainingConfig.from_json(args.config)
    elif Path(AUTO_CONFIG_PATH).exists():
        args.config = AUTO_CONFIG_PATH
        config = TrainingConfig.from_json(AUTO_CONFIG_PATH)
    else:
        config = TrainingConfig()

    # ===================
    # Distributed Setup
    # ===================
    rank, world_size, local_rank = setup_distributed(
        timeout_minutes=config.distributed_timeout_minutes
    )

    # ===================
    # Logging Setup
    # ===================
    logger = setup_logging("logs", rank)

    # Elevate console logging to DEBUG if --debug flag is set
    if args.debug and is_main_process(rank):
        for handler in logger.handlers:
            if isinstance(handler, logging.StreamHandler) and not isinstance(handler, logging.FileHandler):
                handler.setLevel(logging.DEBUG)
        logging.getLogger("midi").setLevel(logging.DEBUG)

    if is_main_process(rank) and args.config:
        logger.info(f"Loaded config from: {args.config}")

    MIDI_DIR = args.midi_dir
    CHECKPOINT_DIR = args.checkpoint_dir

    # Model hyperparameters (from config)
    D_MODEL = config.d_model
    N_HEADS = config.n_heads
    N_LAYERS = config.n_layers
    SEQ_LENGTH = config.seq_length

    # Training hyperparameters (override from args if provided)
    BATCH_SIZE_PER_GPU = args.batch_size if args.batch_size else config.batch_size_per_gpu
    GRADIENT_ACCUMULATION = args.grad_accum if args.grad_accum else config.gradient_accumulation
    EFFECTIVE_BATCH_SIZE = BATCH_SIZE_PER_GPU * world_size * GRADIENT_ACCUMULATION

    # Use custom LR if provided, otherwise use config defaults
    if args.lr is not None:
        LEARNING_RATE = args.lr
    else:
        LEARNING_RATE = config.get_learning_rate(is_lora=args.lora, is_finetune=args.finetune)

    EPOCHS = args.epochs if args.epochs is not None else config.epochs
    VAL_SPLIT = config.val_split
    EARLY_STOPPING_PATIENCE = config.early_stopping_patience
    USE_TAGS = config.use_tags
    USE_COMPILE = config.use_compile

    # Set device for this process
    if world_size > 1:
        DEVICE = torch.device(f"cuda:{local_rank}")
    elif torch.cuda.is_available():
        DEVICE = torch.device("cuda")
    elif torch.backends.mps.is_available():
        DEVICE = torch.device("mps")
    else:
        DEVICE = torch.device("cpu")

    if is_main_process(rank):
        logger.info(f"Using {world_size} GPU(s)")
        logger.info(f"Per-GPU batch size: {BATCH_SIZE_PER_GPU}")
        logger.info(f"Effective batch size: {EFFECTIVE_BATCH_SIZE}")
        logger.info(f"Learning rate: {LEARNING_RATE}")
        logger.info(f"Epochs: {EPOCHS}")
        logger.info(f"Device: {DEVICE}")
        if DEVICE.type == "cuda":
            gpu_name = torch.cuda.get_device_name(DEVICE)
            gpu_memory = torch.cuda.get_device_properties(DEVICE).total_memory / 1e9
            logger.info(f"GPU: {gpu_name} ({gpu_memory:.1f}GB)")
            logger.info("A100 optimizations: TF32, cuDNN benchmark, Flash SDPA enabled")
        if args.load_from:
            logger.info(f"Loading weights from: {args.load_from}")
            if args.lora:
                logger.info(f"LoRA mode: rank={args.lora_rank}, alpha={args.lora_alpha}")
            elif args.finetune:
                logger.info("Fine-tune mode: fresh optimizer, epoch reset")
            if args.freeze_layers > 0:
                logger.info(f"Freezing first {args.freeze_layers} transformer layers")
        logger.debug(f"Model config: d_model={D_MODEL}, n_heads={N_HEADS}, n_layers={N_LAYERS}, seq_length={SEQ_LENGTH}, dropout={config.dropout}")

    # ===================
    # Prepare data
    # ===================
    if is_main_process(rank):
        os.makedirs(CHECKPOINT_DIR, exist_ok=True)

    # Load tokenizer from pretokenization (preserves vocab with discovered artists/genres)
    tokenizer_path = Path(CHECKPOINT_DIR) / "tokenizer.json"
    tokenizer = get_tokenizer(tokenizer_path=str(tokenizer_path), midi_dir=MIDI_DIR)

    # Load pre-tokenized data from cache
    cache_path = Path(CHECKPOINT_DIR) / "token_cache.pkl"

    midi_files = [f for f in Path(MIDI_DIR).glob("**/*.mid") if '__MACOSX' not in f.parts] + \
                 [f for f in Path(MIDI_DIR).glob("**/*.midi") if '__MACOSX' not in f.parts]
    num_midi_files = len(midi_files) if midi_files else None

    cache_result = load_token_cache(cache_path, num_midi_files=num_midi_files, logger=logger if is_main_process(rank) else None)

    if cache_result is None and len(midi_files) == 0:
        if is_main_process(rank):
            logger.error(f"No MIDI files found in '{MIDI_DIR}' and no token cache found!")
            logger.info("Either add .mid files and run pretokenize.py, or provide a token_cache.pkl.")
            logger.info("You can download datasets like:")
            logger.info("  - Lakh MIDI Dataset: https://colinraffel.com/projects/lmd/")
            logger.info("  - MAESTRO: https://magenta.tensorflow.org/datasets/maestro")
        cleanup_distributed()
        return

    if is_main_process(rank):
        if midi_files:
            logger.info(f"Found {len(midi_files)} MIDI files")
        logger.info(f"Tokenizer vocab size: {tokenizer.vocab_size}")
    if cache_result is None:
        if is_main_process(rank):
            logger.error(f"Token cache not found or invalid at '{cache_path}'")
            logger.info("Please run pre-tokenization first:")
            logger.info(f"    python pretokenize.py --midi-dir {MIDI_DIR}")
        cleanup_distributed()
        return

    token_sequences, is_multitrack = cache_result

    if args.max_files:
        token_sequences = token_sequences[:args.max_files]
        if is_main_process(rank):
            logger.info(f"Limiting to {args.max_files} sequences (--max-files)")

    if is_main_process(rank):
        mode_str = "multi-track" if is_multitrack else "single-track"
        logger.info(f"Loaded {len(token_sequences)} {mode_str} sequences from cache")

    # Pre-training data validation gate
    if is_main_process(rank):
        from .validation import validate_training_data

        validation_report = validate_training_data(
            token_sequences=token_sequences,
            vocab=tokenizer.vocab,
            vocab_size=tokenizer.vocab_size,
            is_multitrack=is_multitrack,
            max_seq_len=SEQ_LENGTH,
            max_tracks=16,
            logger=logger,
        )
        for issue in validation_report.warnings:
            logger.warning(f"[DATA] {issue.check_name}: {issue.message}")
        for issue in validation_report.fatals:
            logger.error(f"[DATA] {issue.check_name}: {issue.message}")
        if validation_report.has_fatal:
            logger.error(
                f"Data validation FAILED with {len(validation_report.fatals)} fatal issue(s). "
                "Fix the issues above and re-run pretokenization."
            )
            cleanup_distributed()
            return

    # Split into train/validation sets
    random.seed(42)  # Ensure same split across processes
    random.shuffle(token_sequences)
    if VAL_SPLIT > 0:
        val_size = max(1, int(len(token_sequences) * VAL_SPLIT))
    else:
        val_size = 0
    if val_size > 0:
        train_sequences = token_sequences[val_size:]
        val_sequences = token_sequences[:val_size]
    else:
        train_sequences = token_sequences
        val_sequences = []

    if is_multitrack:
        train_dataset = MultiTrackMIDIDataset(
            train_sequences, seq_length=SEQ_LENGTH, vocab=tokenizer.vocab
        )
        val_dataset = MultiTrackMIDIDataset(
            val_sequences, seq_length=SEQ_LENGTH, vocab=tokenizer.vocab
        ) if val_sequences else None
    else:
        train_dataset = MIDIDataset(train_sequences, seq_length=SEQ_LENGTH)
        val_dataset = MIDIDataset(val_sequences, seq_length=SEQ_LENGTH) if val_sequences else None
    if is_main_process(rank):
        val_count = len(val_dataset) if val_dataset else 0
        logger.info(
            f"Created {len(train_dataset)} training samples, {val_count} validation samples"
        )

    # Use DistributedSampler for multi-GPU
    train_sampler = (
        DistributedSampler(train_dataset, shuffle=True) if world_size > 1 else None
    )
    val_sampler = (
        DistributedSampler(val_dataset, shuffle=False) if world_size > 1 and val_dataset else None
    )

    # MPS benefits from fewer workers; CUDA benefits from more workers + prefetching
    num_workers = 2 if DEVICE.type == "mps" else 8
    prefetch_factor = 2 if DEVICE.type == "cuda" else None

    train_loader = DataLoader(
        train_dataset,
        batch_size=BATCH_SIZE_PER_GPU,
        shuffle=(train_sampler is None),
        sampler=train_sampler,
        num_workers=num_workers,
        pin_memory=(DEVICE.type == "cuda"),
        persistent_workers=True,
        prefetch_factor=prefetch_factor,
        drop_last=True,
    )
    val_loader = DataLoader(
        val_dataset,
        batch_size=BATCH_SIZE_PER_GPU,
        shuffle=False,
        sampler=val_sampler,
        num_workers=num_workers,
        pin_memory=(DEVICE.type == "cuda"),
        persistent_workers=True,
        prefetch_factor=prefetch_factor,
    ) if val_dataset else None

    # ===================
    # Auto-scale model dimensions
    # ===================
    if args.load_from:
        # Must match pretrained checkpoint dimensions
        ckpt_config = peek_checkpoint_config(args.load_from)
        if ckpt_config:
            D_MODEL = ckpt_config.get("d_model", D_MODEL)
            N_HEADS = ckpt_config.get("n_heads", N_HEADS)
            N_LAYERS = ckpt_config.get("n_layers", N_LAYERS)
            if is_main_process(rank):
                logger.info(
                    f"Model dims from pretrained checkpoint: "
                    f"d_model={D_MODEL}, n_heads={N_HEADS}, n_layers={N_LAYERS}"
                )
    else:
        # Check for existing checkpoint (resume scenario)
        ckpt_config = peek_checkpoint_config(CHECKPOINT_DIR)
        if ckpt_config:
            D_MODEL = ckpt_config.get("d_model", D_MODEL)
            N_HEADS = ckpt_config.get("n_heads", N_HEADS)
            N_LAYERS = ckpt_config.get("n_layers", N_LAYERS)
            if is_main_process(rank):
                logger.info(
                    f"Model dims from existing checkpoint: "
                    f"d_model={D_MODEL}, n_heads={N_HEADS}, n_layers={N_LAYERS}"
                )
        else:
            # Fresh training: auto-scale based on dataset size and hardware
            num_samples = len(train_dataset)
            # Compute available training memory for hardware-aware sizing
            available_mem = None
            if DEVICE.type == "cuda":
                _gpu_props = torch.cuda.get_device_properties(DEVICE)
                available_mem = _gpu_props.total_memory / 1e9 * 0.85
            scaled = compute_model_dims(
                num_samples,
                available_memory_gb=available_mem,
                seq_length=SEQ_LENGTH,
                batch_size=BATCH_SIZE_PER_GPU,
                vocab_size=tokenizer.vocab_size,
            )
            D_MODEL = scaled["d_model"]
            N_HEADS = scaled["n_heads"]
            N_LAYERS = scaled["n_layers"]
            if is_main_process(rank):
                step_note = " (stepped up: hardware has capacity)" if scaled.get("stepped_up") else ""
                logger.info(
                    f"Auto-scaled model to '{scaled['tier']}'{step_note} for {num_samples} samples: "
                    f"d_model={D_MODEL}, n_heads={N_HEADS}, n_layers={N_LAYERS}"
                )

    # ===================
    # Initialize model
    # ===================
    DROPOUT = config.dropout

    if is_multitrack:
        model = MultiTrackMusicTransformer(
            vocab_size=tokenizer.vocab_size,
            d_model=D_MODEL,
            n_heads=N_HEADS,
            n_layers=N_LAYERS,
            max_seq_len=SEQ_LENGTH,
            max_tracks=16,
            dropout=DROPOUT,
        ).to(DEVICE)
        if is_main_process(rank):
            logger.info("Using MultiTrackMusicTransformer with cross-track attention")
    else:
        model = MusicTransformer(
            vocab_size=tokenizer.vocab_size,
            d_model=D_MODEL,
            n_heads=N_HEADS,
            n_layers=N_LAYERS,
            max_seq_len=SEQ_LENGTH,
            dropout=DROPOUT,
        ).to(DEVICE)

    # Verify vocab size consistency
    if is_main_process(rank):
        logger.info(f"Tokenizer vocab_size: {tokenizer.vocab_size}")

    # Apply torch.compile() for faster training (before DDP)
    if USE_COMPILE and hasattr(torch, "compile"):
        try:
            compile_mode = "default"
            model = torch.compile(model, mode=compile_mode)
            if is_main_process(rank):
                logger.info(f"Applied torch.compile(mode='{compile_mode}') for faster training")
        except Exception as e:
            if is_main_process(rank):
                logger.warning(f"torch.compile() not available: {e}")

    # Wrap model with DDP for multi-GPU
    if world_size > 1:
        model = DDP(model, device_ids=[local_rank])

    if is_main_process(rank):
        model_for_params = model.module if hasattr(model, "module") else model
        total_params = sum(p.numel() for p in model_for_params.parameters())
        logger.info(f"Model parameters: {total_params:,}")
        logger.info(f"Gradient accumulation steps: {GRADIENT_ACCUMULATION}")

    # ===================
    # Fine-tuning: Load pre-trained weights
    # ===================
    if args.load_from:
        pretrained_ckpt = load_pretrained_checkpoint(
            args.load_from, model, DEVICE, logger if is_main_process(rank) else None
        )
        ckpt_vocab = pretrained_ckpt.get("vocab_size")
        if ckpt_vocab is not None and ckpt_vocab != tokenizer.vocab_size:
            if is_main_process(rank):
                logger.warning(
                    f"VOCAB MISMATCH: checkpoint vocab_size={ckpt_vocab} vs "
                    f"tokenizer vocab_size={tokenizer.vocab_size}. "
                    f"This may cause embedding errors."
                )

        # Enable LoRA if requested (freezes base model, adds trainable adapters)
        if args.lora:
            model_for_lora = model.module if hasattr(model, "module") else model
            enable_lora(
                model_for_lora,
                rank=args.lora_rank,
                alpha=args.lora_alpha,
            )
            lora_count, total_count, trainable_count = count_lora_parameters(model_for_lora)
            if is_main_process(rank):
                logger.info(f"LoRA enabled: {lora_count:,} adapter params, {trainable_count:,} trainable / {total_count:,} total ({100*trainable_count/total_count:.2f}%)")

        # Freeze layers if requested (must be done before optimizer creation)
        elif args.freeze_layers > 0:
            freeze_layers(model, args.freeze_layers, logger if is_main_process(rank) else None)

    # Create optimizer with proper weight decay groups
    decay_params = [p for n, p in model.named_parameters()
                    if p.requires_grad and p.dim() >= 2]
    no_decay_params = [p for n, p in model.named_parameters()
                       if p.requires_grad and p.dim() < 2]
    WEIGHT_DECAY = config.weight_decay
    optimizer = torch.optim.AdamW([
        {"params": decay_params, "weight_decay": WEIGHT_DECAY},
        {"params": no_decay_params, "weight_decay": 0.0},
    ], lr=LEARNING_RATE, fused=(DEVICE.type == "cuda"))

    # ===================
    # Resume from checkpoint
    # ===================
    if args.load_from and (args.finetune or args.lora):
        start_epoch = 1
        best_val_loss = float("inf")
        scheduler_state = None
        if is_main_process(rank):
            mode = "LoRA" if args.lora else "Fine-tune"
            logger.info(f"{mode} mode: starting from epoch 1 with fresh optimizer")
    else:
        start_epoch, best_val_loss, scheduler_state = load_checkpoint(
            CHECKPOINT_DIR, model, optimizer, DEVICE, logger if is_main_process(rank) else None
        )
        if args.lr is not None and start_epoch > 1:
            for param_group in optimizer.param_groups:
                param_group["lr"] = LEARNING_RATE
                param_group["initial_lr"] = LEARNING_RATE
            scheduler_state = None
            if is_main_process(rank):
                logger.info(f"Overriding restored LR with --lr {LEARNING_RATE:.2e} (fresh scheduler)")
    epochs_without_improvement = 0

    # ===================
    # LR Scheduler
    # ===================
    num_batches = len(train_loader)
    steps_per_epoch = num_batches // GRADIENT_ACCUMULATION
    if num_batches % GRADIENT_ACCUMULATION != 0:
        steps_per_epoch += 1
    total_steps = steps_per_epoch * EPOCHS
    WARMUP_PCT = 0.0 if args.no_warmup else config.warmup_pct
    warmup_steps = int(total_steps * WARMUP_PCT)

    eta_min = LEARNING_RATE * 0.1

    if config.scheduler == "onecycle":
        scheduler = OneCycleLR(
            optimizer,
            max_lr=LEARNING_RATE,
            steps_per_epoch=steps_per_epoch,
            epochs=EPOCHS,
            pct_start=WARMUP_PCT,
        )
        scheduler_name = f"OneCycleLR with {WARMUP_PCT:.0%} warmup"
    else:
        if warmup_steps > 0:
            warmup_scheduler = LambdaLR(
                optimizer, lr_lambda=lambda step: min(1.0, step / max(1, warmup_steps))
            )
            cosine_scheduler = CosineAnnealingLR(
                optimizer, T_max=total_steps - warmup_steps, eta_min=eta_min,
            )
            scheduler = SequentialLR(
                optimizer,
                schedulers=[warmup_scheduler, cosine_scheduler],
                milestones=[warmup_steps],
            )
            scheduler_name = f"CosineAnnealing with {WARMUP_PCT:.0%} linear warmup ({warmup_steps} steps)"
        else:
            scheduler = CosineAnnealingLR(optimizer, T_max=total_steps, eta_min=eta_min)
            scheduler_name = "CosineAnnealing (no warmup)"

    if scheduler_state is not None:
        scheduler.load_state_dict(scheduler_state)
        if is_main_process(rank):
            logger.info(f"LR scheduler: restored from checkpoint (epoch {start_epoch - 1})")
    if is_main_process(rank):
        logger.info(f"LR scheduler: {scheduler_name} over {EPOCHS} epochs ({steps_per_epoch} steps/epoch)")

    # ===================
    # Training loop
    # ===================

    # GradScaler for float16 on MPS (bfloat16 on CUDA doesn't need it)
    use_fp16_scaler = DEVICE.type == "mps"
    scaler = None
    if use_fp16_scaler:
        try:
            scaler = torch.amp.GradScaler("cpu")
            if is_main_process(rank):
                logger.info("GradScaler enabled for float16 on MPS")
        except Exception as e:
            if is_main_process(rank):
                logger.warning(f"GradScaler not available on this PyTorch version: {e}")

    if is_main_process(rank):
        tokens_per_step = EFFECTIVE_BATCH_SIZE * SEQ_LENGTH
        logger.info(f"Tokens per optimizer step: {tokens_per_step:,}")
        if start_epoch > 1:
            logger.info(f"Resuming training from epoch {start_epoch}...")
        else:
            logger.info("Starting training...")

    optimizer.zero_grad(set_to_none=True)

    training_start_time = time.time()

    # Loss history for epoch health diagnostics
    loss_history = []  # list of (epoch, train_loss, val_loss)

    # Per-step loss CSV for debugging
    loss_csv_path = None
    if is_main_process(rank):
        import csv
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        loss_csv_path = str(log_dir / "step_losses.csv")
        if not Path(loss_csv_path).exists():
            with open(loss_csv_path, "w", newline="") as f:
                csv.writer(f).writerow(["epoch", "batch", "loss", "grad_norm"])
            logger.info(f"Per-step loss log: {loss_csv_path}")

    for epoch in range(start_epoch, EPOCHS + 1):
        if train_sampler is not None:
            train_sampler.set_epoch(epoch)

        epoch_start = time.time()
        train_loss, train_metrics = train_epoch(
            model,
            train_loader,
            optimizer,
            DEVICE,
            epoch,
            rank=rank,
            grad_accum=GRADIENT_ACCUMULATION,
            is_multitrack=is_multitrack,
            grad_clip_norm=config.grad_clip_norm,
            scheduler=scheduler,
            scaler=scaler,
            loss_csv_path=loss_csv_path,
        )
        train_time = time.time() - epoch_start

        val_start = time.time()
        if val_loader:
            val_loss = validate(model, val_loader, DEVICE, is_multitrack=is_multitrack)
        else:
            val_loss = train_loss
        val_time = time.time() - val_start

        if is_main_process(rank):
            if val_loader:
                logger.info(
                    f"Epoch {epoch} - train loss: {train_loss:.4f}, val loss: {val_loss:.4f}"
                )
            else:
                logger.info(
                    f"Epoch {epoch} - train loss: {train_loss:.4f} (no validation set)"
                )

            # Diagnostics
            current_lr = optimizer.param_groups[0]['lr']
            tokens_this_epoch = train_metrics["num_batches"] * BATCH_SIZE_PER_GPU * SEQ_LENGTH
            tokens_per_sec = tokens_this_epoch / train_time if train_time > 0 else 0
            skipped = train_metrics.get("skipped_steps", 0)
            skipped_str = f" | skipped_steps: {skipped}" if skipped > 0 else ""
            logger.info(
                f"  lr: {current_lr:.2e} | "
                f"grad_norm: avg={train_metrics['grad_norm_avg']:.2f}, max={train_metrics['grad_norm_max']:.2f} | "
                f"non-pad: {train_metrics['non_pad_pct']:.1f}%{skipped_str}"
            )
            logger.info(
                f"  time: {train_time:.0f}s train, {val_time:.0f}s val | "
                f"throughput: {tokens_per_sec:,.0f} tok/s"
            )
            if DEVICE.type == "cuda":
                peak_mem_gb = torch.cuda.max_memory_allocated(DEVICE) / 1e9
                logger.info(f"  GPU peak memory: {peak_mem_gb:.1f}GB")
                torch.cuda.reset_peak_memory_stats(DEVICE)

            # Epoch health summary
            import math as _math
            loss_history.append((epoch, train_loss, val_loss))
            monitor_loss = val_loss if val_loader else train_loss
            perplexity = _math.exp(monitor_loss) if monitor_loss < 20 else float("inf")

            # Detect training phase from LR schedule position and loss behavior
            elapsed_steps = (epoch - start_epoch + 1) * steps_per_epoch
            progress_pct = (epoch - start_epoch + 1) / max(1, EPOCHS - start_epoch + 1)
            in_warmup = elapsed_steps <= warmup_steps and warmup_steps > 0

            if in_warmup:
                phase = "WARMUP"
            elif len(loss_history) >= 5:
                recent5 = [h[2] if val_loader else h[1] for h in loss_history[-5:]]
                avg_delta_5 = (recent5[-1] - recent5[0]) / 4
                if avg_delta_5 > -1e-4:
                    # Loss flat or rising over last 5 epochs
                    if val_loader and val_loss > train_loss * 1.3:
                        phase = "OVERFIT"
                    else:
                        phase = "PLATEAU"
                elif abs(avg_delta_5) < abs(recent5[0]) * 0.005:
                    # Improving but slowly (< 0.5% per epoch)
                    phase = "CONVERGING"
                else:
                    phase = "ACTIVE"
            elif len(loss_history) >= 2:
                prev_loss = loss_history[-2][2] if val_loader else loss_history[-2][1]
                if monitor_loss < prev_loss:
                    phase = "ACTIVE"
                else:
                    phase = "WARMUP" if progress_pct < 0.1 else "ACTIVE"
            else:
                phase = "WARMUP" if in_warmup else "ACTIVE"

            health_parts = [f"phase={phase}", f"ppl={perplexity:.1f}"]

            if len(loss_history) >= 2:
                prev_loss = loss_history[-2][2] if val_loader else loss_history[-2][1]
                delta = monitor_loss - prev_loss
                pct = (delta / prev_loss) * 100 if prev_loss != 0 else 0
                direction = "v" if delta < 0 else "^"
                health_parts.append(f"delta={delta:+.4f} ({pct:+.1f}%) {direction}")

            if len(loss_history) >= 5:
                recent = [h[2] if val_loader else h[1] for h in loss_history[-5:]]
                avg_delta = (recent[-1] - recent[0]) / 4
                health_parts.append(f"5ep_trend={avg_delta:+.4f}/ep")

            health_parts.append(f"ep={epoch}/{EPOCHS} ({progress_pct:.0%})")

            # Flag problems
            flags = []
            if len(loss_history) >= 3:
                recent3 = [h[2] if val_loader else h[1] for h in loss_history[-3:]]
                if all(recent3[i] >= recent3[i - 1] - 1e-4 for i in range(1, len(recent3))):
                    flags.append("STALL")
            if train_metrics["grad_norm_max"] > 10 * train_metrics["grad_norm_avg"] and train_metrics["grad_norm_avg"] > 0:
                flags.append("GRAD_SPIKE")
            if train_metrics.get("skipped_steps", 0) > train_metrics["num_batches"] * 0.1:
                flags.append("MANY_SKIPS")
            if phase == "OVERFIT":
                flags.append("OVERFIT")

            flag_str = f" | flags: {','.join(flags)}" if flags else ""
            logger.info(f"  health: {' | '.join(health_parts)}{flag_str}")

            # Save checkpoint every 5 epochs
            if epoch % 5 == 0:
                if args.lora:
                    save_lora_adapter(
                        model,
                        epoch,
                        val_loss,
                        f"{CHECKPOINT_DIR}/lora_epoch_{epoch}.pt",
                        args.lora_rank,
                        args.lora_alpha,
                        logger,
                    )
                else:
                    save_checkpoint(
                        model,
                        optimizer,
                        epoch,
                        val_loss,
                        tokenizer,
                        f"{CHECKPOINT_DIR}/checkpoint_epoch_{epoch}.pt",
                        logger,
                        scheduler=scheduler,
                    )

            # Save best model
            if val_loss < best_val_loss:
                best_val_loss = val_loss
                epochs_without_improvement = 0
                if args.lora:
                    save_lora_adapter(
                        model,
                        epoch,
                        val_loss,
                        f"{CHECKPOINT_DIR}/lora_adapter.pt",
                        args.lora_rank,
                        args.lora_alpha,
                        logger,
                    )
                else:
                    save_checkpoint(
                        model,
                        optimizer,
                        epoch,
                        val_loss,
                        tokenizer,
                        f"{CHECKPOINT_DIR}/best_model.pt",
                        logger,
                        scheduler=scheduler,
                    )
            else:
                epochs_without_improvement += 1
                if epochs_without_improvement >= EARLY_STOPPING_PATIENCE:
                    logger.info(
                        f"Early stopping triggered after {epochs_without_improvement} epochs without improvement"
                    )
                    break

        # Sync best_val_loss across processes
        if world_size > 1:
            dist.barrier()

    if is_main_process(rank):
        import math as _math

        total_training_time = time.time() - training_start_time
        hours, remainder = divmod(int(total_training_time), 3600)
        minutes, seconds = divmod(remainder, 60)
        time_str = f"{hours}h {minutes:02d}m {seconds:02d}s" if hours else f"{minutes}m {seconds:02d}s"

        # Compute final stats
        model_for_params = model.module if hasattr(model, "module") else model
        total_params = sum(p.numel() for p in model_for_params.parameters())
        trainable_params = sum(p.numel() for p in model_for_params.parameters() if p.requires_grad)

        final_epoch = loss_history[-1][0] if loss_history else epoch
        final_train_loss = loss_history[-1][1] if loss_history else 0
        final_val_loss = loss_history[-1][2] if loss_history else 0

        best_epoch = min(loss_history, key=lambda h: h[2] if val_loader else h[1])[0] if loss_history else 0
        best_ppl = _math.exp(best_val_loss) if best_val_loss < 20 else float("inf")
        _final_loss = final_val_loss if val_loader else final_train_loss
        final_ppl = _math.exp(_final_loss) if _final_loss < 20 else float("inf")

        early_stopped = epochs_without_improvement >= EARLY_STOPPING_PATIENCE
        completion_str = f"early stopped at {final_epoch}/{EPOCHS}" if early_stopped else f"{final_epoch}/{EPOCHS}"

        separator = "=" * 60
        logger.info(separator)
        logger.info("TRAINING COMPLETE")
        logger.info(separator)

        # Model
        model_type = "MultiTrackMusicTransformer" if is_multitrack else "MusicTransformer"
        logger.info(f"  Model:          {model_type}")
        logger.info(f"  Parameters:     {total_params:,} total, {trainable_params:,} trainable")
        logger.info(f"  Architecture:   d={D_MODEL}, heads={N_HEADS}, layers={N_LAYERS}, seq={SEQ_LENGTH}")
        logger.info(f"  Vocab size:     {tokenizer.vocab_size:,}")

        # Hardware
        device_str = str(DEVICE)
        if DEVICE.type == "cuda":
            gpu_name = torch.cuda.get_device_name(DEVICE)
            device_str = f"{gpu_name} x{world_size}" if world_size > 1 else gpu_name
        logger.info(f"  Device:         {device_str}")

        # Training config
        logger.info(f"  Batch size:     {BATCH_SIZE_PER_GPU} x {world_size} GPU(s) x {GRADIENT_ACCUMULATION} accum = {EFFECTIVE_BATCH_SIZE} effective")
        logger.info(f"  Learning rate:  {LEARNING_RATE:.2e} ({config.scheduler} scheduler)")
        if args.lora:
            logger.info(f"  LoRA:           rank={args.lora_rank}, alpha={args.lora_alpha}")
        if args.freeze_layers > 0:
            logger.info(f"  Frozen layers:  {args.freeze_layers}")

        # Dataset
        val_count = len(val_dataset) if val_dataset else 0
        logger.info(f"  Dataset:        {len(train_dataset):,} train, {val_count:,} val ({len(token_sequences):,} sequences)")

        # Results
        logger.info(separator)
        logger.info(f"  Epochs:         {completion_str}")
        logger.info(f"  Best loss:      {best_val_loss:.4f} (epoch {best_epoch}, ppl={best_ppl:.2f})")
        logger.info(f"  Final loss:     train={final_train_loss:.4f}" + (f", val={final_val_loss:.4f}" if val_loader else ""))
        logger.info(f"  Final ppl:      {final_ppl:.2f}")
        logger.info(f"  Wall time:      {time_str}")
        avg_epoch_time = total_training_time / max(1, len(loss_history))
        logger.info(f"  Avg epoch time: {avg_epoch_time:.0f}s")
        avg_tok_per_sec = (len(loss_history) * len(train_loader) * BATCH_SIZE_PER_GPU * SEQ_LENGTH) / total_training_time if total_training_time > 0 else 0
        logger.info(f"  Avg throughput: {avg_tok_per_sec:,.0f} tok/s")

        # Loss progression (first, best, last)
        if len(loss_history) >= 2:
            logger.info(separator)
            logger.info("  Loss progression:")
            first = loss_history[0]
            logger.info(f"    Epoch {first[0]:>3d}: train={first[1]:.4f}" + (f"  val={first[2]:.4f}" if val_loader else ""))
            if best_epoch != first[0] and best_epoch != final_epoch:
                best_entry = next(h for h in loss_history if h[0] == best_epoch)
                logger.info(f"    Epoch {best_entry[0]:>3d}: train={best_entry[1]:.4f}" + (f"  val={best_entry[2]:.4f}" if val_loader else "") + "  <- best")
            last = loss_history[-1]
            best_marker = "  <- best" if best_epoch == final_epoch else ""
            logger.info(f"    Epoch {last[0]:>3d}: train={last[1]:.4f}" + (f"  val={last[2]:.4f}" if val_loader else "") + best_marker)

        # Saved artifacts
        logger.info(separator)
        if args.lora:
            logger.info(f"  Best adapter:   {CHECKPOINT_DIR}/lora_adapter.pt")
        else:
            logger.info(f"  Best model:     {CHECKPOINT_DIR}/best_model.pt")
        if loss_csv_path:
            logger.info(f"  Step losses:    {loss_csv_path}")
        logger.info(separator)

        # Write training_summary.json alongside the model
        import json as _json

        best_artifact = (
            f"{CHECKPOINT_DIR}/lora_adapter.pt" if args.lora
            else f"{CHECKPOINT_DIR}/best_model.pt"
        )
        summary = {
            "model": {
                "type": model_type,
                "parameters_total": total_params,
                "parameters_trainable": trainable_params,
                "d_model": D_MODEL,
                "n_heads": N_HEADS,
                "n_layers": N_LAYERS,
                "seq_length": SEQ_LENGTH,
                "vocab_size": tokenizer.vocab_size,
                "dropout": DROPOUT,
            },
            "training": {
                "device": device_str,
                "world_size": world_size,
                "batch_size_per_gpu": BATCH_SIZE_PER_GPU,
                "gradient_accumulation": GRADIENT_ACCUMULATION,
                "effective_batch_size": EFFECTIVE_BATCH_SIZE,
                "learning_rate": LEARNING_RATE,
                "scheduler": config.scheduler,
                "weight_decay": WEIGHT_DECAY,
                "warmup_pct": WARMUP_PCT,
                "lora": {
                    "rank": args.lora_rank,
                    "alpha": args.lora_alpha,
                } if args.lora else None,
                "frozen_layers": args.freeze_layers if args.freeze_layers > 0 else None,
            },
            "dataset": {
                "train_samples": len(train_dataset),
                "val_samples": val_count,
                "total_sequences": len(token_sequences),
                "mode": "multi-track" if is_multitrack else "single-track",
            },
            "results": {
                "epochs_completed": final_epoch,
                "epochs_total": EPOCHS,
                "early_stopped": early_stopped,
                "best_loss": round(best_val_loss, 6),
                "best_epoch": best_epoch,
                "best_perplexity": round(best_ppl, 4) if best_ppl != float("inf") else None,
                "final_train_loss": round(final_train_loss, 6),
                "final_val_loss": round(final_val_loss, 6) if val_loader else None,
                "final_perplexity": round(final_ppl, 4) if final_ppl != float("inf") else None,
                "wall_time_seconds": round(total_training_time, 1),
                "avg_epoch_time_seconds": round(avg_epoch_time, 1),
                "avg_throughput_tok_s": int(avg_tok_per_sec),
            },
            "loss_history": [
                {
                    "epoch": h[0],
                    "train_loss": round(h[1], 6),
                    "val_loss": round(h[2], 6) if val_loader else None,
                }
                for h in loss_history
            ],
            "artifacts": {
                "best_model": best_artifact,
                "step_losses": loss_csv_path,
            },
            "completed_at": datetime.now().isoformat(),
        }
        summary_path = Path(CHECKPOINT_DIR) / "training_summary.json"
        with open(summary_path, "w") as f:
            _json.dump(summary, f, indent=2)
        logger.info(f"Training summary saved to {summary_path}")

    cleanup_distributed()


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        logger = logging.getLogger("train")
        if logger.handlers:
            logger.exception(f"Training crashed with error: {e}")
        else:
            crash_log = Path("logs") / f"crash_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
            crash_log.parent.mkdir(exist_ok=True)
            with open(crash_log, "w") as f:
                f.write(f"Training crashed at {datetime.now()}\n")
                f.write(f"Error: {e}\n\n")
                f.write("Full traceback:\n")
                traceback.print_exc(file=f)
            print(f"Crash log written to {crash_log}")
        raise
