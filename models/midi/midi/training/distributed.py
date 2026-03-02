"""Distributed training utilities."""

import logging
import os
import sys
from datetime import datetime, timedelta
from pathlib import Path

import torch.distributed as dist
import torch


def setup_logging(log_dir: str = "logs", rank: int = 0) -> logging.Logger:
    """Set up logging to both file and console."""
    logger = logging.getLogger("train")
    logger.setLevel(logging.DEBUG)
    logger.propagate = False

    # Only log to file on main process
    if rank == 0:
        os.makedirs(log_dir, exist_ok=True)
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_file = Path(log_dir) / f"train_{timestamp}.log"

        # File handler - captures everything
        file_handler = logging.FileHandler(log_file)
        file_handler.setLevel(logging.DEBUG)
        file_formatter = logging.Formatter(
            "%(asctime)s | %(levelname)s | %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S"
        )
        file_handler.setFormatter(file_formatter)
        logger.addHandler(file_handler)

        # Console handler - info and above
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setLevel(logging.INFO)
        console_formatter = logging.Formatter(
            "%(asctime)s - %(levelname)s - %(message)s"
        )
        console_handler.setFormatter(console_formatter)
        logger.addHandler(console_handler)

        logger.info(f"Logging to {log_file}")

    return logger


def setup_distributed(timeout_minutes: int = 30):
    """Initialize distributed training."""
    if "RANK" in os.environ:
        local_rank = int(os.environ["LOCAL_RANK"])
        torch.cuda.set_device(local_rank)
        dist.init_process_group(
            "nccl",
            timeout=timedelta(minutes=timeout_minutes),
            device_id=torch.device(f"cuda:{local_rank}"),
        )
        rank = dist.get_rank()
        world_size = dist.get_world_size()
        return rank, world_size, local_rank
    return 0, 1, 0


def cleanup_distributed():
    """Clean up distributed training."""
    if dist.is_initialized():
        dist.destroy_process_group()


def is_main_process(rank):
    """Check if this is the main process."""
    return rank == 0
