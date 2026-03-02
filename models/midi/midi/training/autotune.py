"""
Auto-tuning configuration generator.

Analyzes hardware and dataset to produce an optimized TrainingConfig JSON file.
Heuristics are derived from the hand-crafted presets in configs/.

Usage:
    python3 -m midi.training.autotune --midi-dir midi_files --output configs/auto.json
    python3 -m midi.training.autotune --cache checkpoints/token_cache.pkl --output configs/auto.json
    python3 -m midi.training.autotune --midi-dir midi_files --dry-run
"""

import argparse
import json
import os
import pickle
import platform
import statistics
import subprocess
from dataclasses import asdict, dataclass
from pathlib import Path

import torch

from .config import TrainingConfig, compute_model_dims, estimate_model_memory_gb


@dataclass
class HardwareInfo:
    """Detected hardware profile."""

    device_type: str  # "cuda", "mps", "cpu"
    device_name: str
    gpu_memory_gb: float  # per-GPU memory (0 for CPU)
    total_memory_gb: float  # system RAM
    gpu_count: int
    cpu_count: int
    platform_os: str  # "Darwin", "Linux", etc.


@dataclass
class DatasetInfo:
    """Analyzed dataset profile."""

    num_files: int
    is_multitrack: bool
    size_tier: str  # "small", "medium", "large"
    seq_length_min: int | None = None
    seq_length_max: int | None = None
    seq_length_median: int | None = None
    seq_length_mean: int | None = None
    total_tokens: int | None = None
    source: str = "scan"  # "cache" or "scan"


def _get_macos_memory_gb() -> float:
    """Get total system memory on macOS via sysctl."""
    try:
        output = subprocess.check_output(
            ["sysctl", "-n", "hw.memsize"], text=True
        ).strip()
        return int(output) / 1e9
    except (subprocess.SubprocessError, ValueError):
        return 16.0  # conservative fallback


def _get_macos_chip_name() -> str:
    """Get Apple Silicon chip name on macOS."""
    try:
        output = subprocess.check_output(
            ["sysctl", "-n", "machdep.cpu.brand_string"], text=True
        ).strip()
        return output
    except (subprocess.SubprocessError, ValueError):
        return "Apple Silicon"


def _get_linux_memory_gb() -> float:
    """Get total system memory on Linux via /proc/meminfo."""
    try:
        with open("/proc/meminfo") as f:
            for line in f:
                if line.startswith("MemTotal:"):
                    # Format: "MemTotal:       16384000 kB"
                    kb = int(line.split()[1])
                    return kb / 1e6
    except (OSError, ValueError):
        pass
    return 16.0


def detect_hardware() -> HardwareInfo:
    """Detect available hardware and return a HardwareInfo profile."""
    platform_os = platform.system()
    cpu_count = os.cpu_count() or 1

    # CUDA path
    if torch.cuda.is_available():
        gpu_count = torch.cuda.device_count()
        props = torch.cuda.get_device_properties(0)
        device_name = props.name
        gpu_memory_gb = props.total_memory / 1e9

        if platform_os == "Linux":
            total_memory_gb = _get_linux_memory_gb()
        elif platform_os == "Darwin":
            total_memory_gb = _get_macos_memory_gb()
        else:
            total_memory_gb = 32.0

        return HardwareInfo(
            device_type="cuda",
            device_name=device_name,
            gpu_memory_gb=gpu_memory_gb,
            total_memory_gb=total_memory_gb,
            gpu_count=gpu_count,
            cpu_count=cpu_count,
            platform_os=platform_os,
        )

    # MPS path (Apple Silicon)
    if hasattr(torch.backends, "mps") and torch.backends.mps.is_available():
        total_memory_gb = _get_macos_memory_gb()
        device_name = _get_macos_chip_name()

        return HardwareInfo(
            device_type="mps",
            device_name=device_name,
            gpu_memory_gb=total_memory_gb,  # unified memory
            total_memory_gb=total_memory_gb,
            gpu_count=1,
            cpu_count=cpu_count,
            platform_os=platform_os,
        )

    # CPU fallback
    if platform_os == "Darwin":
        total_memory_gb = _get_macos_memory_gb()
        device_name = _get_macos_chip_name()
    elif platform_os == "Linux":
        total_memory_gb = _get_linux_memory_gb()
        device_name = platform.processor() or "CPU"
    else:
        total_memory_gb = 16.0
        device_name = platform.processor() or "CPU"

    return HardwareInfo(
        device_type="cpu",
        device_name=device_name,
        gpu_memory_gb=0.0,
        total_memory_gb=total_memory_gb,
        gpu_count=0,
        cpu_count=cpu_count,
        platform_os=platform_os,
    )


def analyze_dataset(
    midi_dir: str | None = None, cache_path: str | None = None
) -> DatasetInfo:
    """Analyze dataset from a token cache or MIDI directory scan."""
    # Try cache first
    if cache_path and Path(cache_path).exists():
        try:
            with open(cache_path, "rb") as f:
                data = pickle.load(f)

            if isinstance(data, dict) and "sequences" in data:
                sequences = data["sequences"]
                is_multitrack = data.get("multitrack", False)
                num_files = data.get("file_count", len(sequences))

                # Compute sequence length stats
                if is_multitrack:
                    lengths = [len(seq[0]) for seq in sequences if seq]
                else:
                    lengths = [len(seq) for seq in sequences if seq]

                if lengths:
                    total_tokens = sum(lengths)
                    info = DatasetInfo(
                        num_files=num_files,
                        is_multitrack=is_multitrack,
                        size_tier=_classify_size(num_files),
                        seq_length_min=min(lengths),
                        seq_length_max=max(lengths),
                        seq_length_median=int(statistics.median(lengths)),
                        seq_length_mean=int(statistics.mean(lengths)),
                        total_tokens=total_tokens,
                        source="cache",
                    )
                    return info
        except (pickle.UnpicklingError, OSError, KeyError, IndexError):
            pass  # fall through to directory scan

    # Directory scan
    if midi_dir:
        midi_path = Path(midi_dir)
        midi_files = [f for f in midi_path.glob("**/*.mid") if '__MACOSX' not in f.parts] + \
                     [f for f in midi_path.glob("**/*.midi") if '__MACOSX' not in f.parts]
        num_files = len(midi_files)
        if num_files == 0:
            raise ValueError(f"No MIDI files found in '{midi_dir}'")

        return DatasetInfo(
            num_files=num_files,
            is_multitrack=True,  # default assumption
            size_tier=_classify_size(num_files),
            source="scan",
        )

    raise ValueError("At least one of midi_dir or cache_path must be provided")


def _classify_size(num_files: int) -> str:
    """Classify dataset into size tiers."""
    if num_files < 500:
        return "small"
    elif num_files < 5000:
        return "medium"
    return "large"


def generate_config(
    hw: HardwareInfo, ds: DatasetInfo, vocab_size: int = 2000
) -> dict:
    """Generate an optimized TrainingConfig dict from hardware and dataset info."""
    config = {}

    # --- Sequence length ---
    if hw.device_type == "mps":
        config["seq_length"] = 2048
    elif hw.device_type == "cuda":
        config["seq_length"] = 8192
    else:
        config["seq_length"] = 1024

    # --- Batch size per GPU ---
    if hw.device_type == "cuda":
        if hw.gpu_memory_gb >= 80:
            batch_size = 24
        elif hw.gpu_memory_gb >= 35:
            batch_size = 12
        elif hw.gpu_memory_gb >= 20:
            batch_size = 8
        elif hw.gpu_memory_gb >= 10:
            batch_size = 4
        else:
            batch_size = 2
        # Multi-GPU: reduce per-GPU batch to leave room for DDP overhead
        if hw.gpu_count >= 8:
            batch_size = max(2, batch_size // 2)
        elif hw.gpu_count >= 4:
            batch_size = max(2, batch_size * 3 // 4)
    elif hw.device_type == "mps":
        if hw.gpu_memory_gb >= 96:
            batch_size = 16
        elif hw.gpu_memory_gb >= 32:
            batch_size = 8
        else:
            batch_size = 4
    else:
        batch_size = 2

    # --- Model architecture (unified with compute_model_dims) ---
    if hw.device_type == "cpu":
        # CPU is compute-limited; always use the smallest model
        config["d_model"] = 256
        config["n_heads"] = 4
        config["n_layers"] = 6
    else:
        # Estimate training sample count from dataset info
        if ds.total_tokens is not None:
            estimated_samples = max(
                ds.num_files,
                int(ds.total_tokens * 0.9 / config["seq_length"]),
            )
        else:
            # Without token stats, approximate chunks per file
            estimated_samples = ds.num_files * 5

        available_mem = _available_training_memory(hw)
        scaled = compute_model_dims(
            estimated_samples,
            available_memory_gb=available_mem,
            seq_length=config["seq_length"],
            batch_size=batch_size,
            vocab_size=vocab_size,
        )
        config["d_model"] = scaled["d_model"]
        config["n_heads"] = scaled["n_heads"]
        config["n_layers"] = scaled["n_layers"]

    # Validate against memory estimate and reduce batch size if needed
    estimated_mem = estimate_model_memory_gb(
        d_model=config["d_model"],
        n_layers=config["n_layers"],
        vocab_size=vocab_size,
        seq_length=config["seq_length"],
        batch_size=batch_size,
    )
    available_mem = _available_training_memory(hw)
    while batch_size > 1 and estimated_mem > available_mem:
        batch_size = max(1, batch_size - 1)
        estimated_mem = estimate_model_memory_gb(
            d_model=config["d_model"],
            n_layers=config["n_layers"],
            vocab_size=vocab_size,
            seq_length=config["seq_length"],
            batch_size=batch_size,
        )

    config["batch_size_per_gpu"] = batch_size

    # --- Gradient accumulation ---
    target_effective = {"small": 64, "medium": 80, "large": 96}[ds.size_tier]
    world_size = hw.gpu_count if hw.device_type == "cuda" and hw.gpu_count > 0 else 1
    gradient_accumulation = max(1, round(target_effective / (batch_size * world_size)))
    gradient_accumulation = max(1, min(16, gradient_accumulation))
    config["gradient_accumulation"] = gradient_accumulation

    # --- Learning rate (dataset-size driven) ---
    if ds.size_tier == "small":
        config["learning_rate"] = 5e-5
        config["learning_rate_finetune"] = 1e-5
        config["learning_rate_lora"] = 5e-5
    elif ds.size_tier == "medium":
        if hw.device_type == "cuda" and hw.gpu_memory_gb >= 80:
            config["learning_rate"] = 1e-4
        else:
            config["learning_rate"] = 3e-5
        config["learning_rate_finetune"] = 1e-5
        config["learning_rate_lora"] = 1e-4
    else:
        config["learning_rate"] = 3e-4
        config["learning_rate_finetune"] = 3e-5
        config["learning_rate_lora"] = 1e-4

    # --- Regularization ---
    if ds.size_tier == "small":
        config["dropout"] = 0.2
        config["warmup_pct"] = 0.15
    elif ds.size_tier == "medium":
        config["dropout"] = 0.15
        config["warmup_pct"] = 0.10
    else:
        config["dropout"] = 0.1
        config["warmup_pct"] = 0.05

    config["weight_decay"] = 0.1
    config["grad_clip_norm"] = 1.0

    # --- Training schedule ---
    if ds.size_tier == "small":
        config["epochs"] = 20
        config["early_stopping_patience"] = 5
    elif ds.size_tier == "medium":
        config["epochs"] = 30 if (hw.device_type == "cuda" and hw.gpu_memory_gb >= 80) else 15
        config["early_stopping_patience"] = 7
    else:
        config["epochs"] = 8 if hw.gpu_count >= 4 else 12
        config["early_stopping_patience"] = 3 if hw.gpu_count >= 4 else 7

    # --- Features ---
    config["use_compile"] = hw.device_type == "cuda"
    config["use_tags"] = True
    config["scheduler"] = "cosine"
    config["val_split"] = 0.1
    config["distributed_timeout_minutes"] = 60 if hw.gpu_count > 1 else 30

    return config


def _available_training_memory(hw: HardwareInfo) -> float:
    """Estimate available memory for training in GB with safety margins."""
    if hw.device_type == "cuda":
        return hw.gpu_memory_gb * 0.85  # 15% headroom for CUDA overhead
    elif hw.device_type == "mps":
        return hw.gpu_memory_gb * 0.60  # 40% reserved for macOS + system
    else:
        return hw.total_memory_gb * 0.50


def _generate_description(hw: HardwareInfo, ds: DatasetInfo) -> str:
    """Produce a human-readable description string for the config."""
    parts = []

    if hw.gpu_count > 1:
        parts.append(f"{hw.gpu_count}x {hw.device_name}")
    else:
        parts.append(hw.device_name)

    if hw.device_type == "mps":
        parts.append(f"{hw.gpu_memory_gb:.0f}GB unified memory")
        parts.append("MPS device, no torch.compile")
    elif hw.device_type == "cuda":
        parts.append(f"{hw.gpu_memory_gb:.0f}GB")
        parts.append("CUDA with torch.compile")
    else:
        parts.append(f"{hw.total_memory_gb:.0f}GB RAM")
        parts.append("CPU only")

    parts.append(f"{ds.num_files} file {ds.size_tier} dataset")
    parts.append("auto-tuned")

    return " - ".join(parts)


def build_output_dict(
    config_data: dict, hw: HardwareInfo, ds: DatasetInfo
) -> dict:
    """Combine config values with metadata fields for JSON output."""
    output = {}

    # Metadata (prefixed with _ so TrainingConfig.from_json ignores them)
    output["_description"] = _generate_description(hw, ds)
    output["_hardware"] = {
        "device_type": hw.device_type,
        "device_name": hw.device_name,
        "gpu_memory_gb": round(hw.gpu_memory_gb, 1),
        "gpu_count": hw.gpu_count,
        "total_memory_gb": round(hw.total_memory_gb, 1),
    }
    dataset_meta = {
        "num_files": ds.num_files,
        "size_tier": ds.size_tier,
        "is_multitrack": ds.is_multitrack,
        "source": ds.source,
    }
    if ds.seq_length_median is not None:
        dataset_meta["seq_length_median"] = ds.seq_length_median
        dataset_meta["seq_length_max"] = ds.seq_length_max
        dataset_meta["total_tokens"] = ds.total_tokens
    output["_dataset_info"] = dataset_meta

    # Actual config fields
    output.update(config_data)
    return output


def print_summary(config_data: dict, hw: HardwareInfo, ds: DatasetInfo) -> None:
    """Print a human-readable summary of the auto-tuned config."""
    print("=" * 60)
    print("  MIDI Training Auto-Tune Results")
    print("=" * 60)

    print(f"\nHardware detected:")
    print(f"  Device:     {hw.device_name} ({hw.device_type})")
    mem_str = f"{hw.gpu_memory_gb:.1f} GB"
    if hw.gpu_count > 1:
        mem_str += f" x {hw.gpu_count}"
    print(f"  GPU memory: {mem_str}")
    print(f"  System RAM: {hw.total_memory_gb:.1f} GB")

    print(f"\nDataset analyzed ({ds.source}):")
    print(f"  Files:      {ds.num_files}")
    print(f"  Size tier:  {ds.size_tier}")
    print(f"  Multitrack: {ds.is_multitrack}")
    if ds.seq_length_median is not None:
        print(
            f"  Seq lengths: min={ds.seq_length_min}, "
            f"median={ds.seq_length_median}, max={ds.seq_length_max}"
        )
        if ds.total_tokens is not None:
            print(f"  Total tokens: {ds.total_tokens:,}")

    print(f"\nGenerated config:")
    print(
        f"  Model:       d={config_data['d_model']}, "
        f"heads={config_data['n_heads']}, layers={config_data['n_layers']}"
    )
    print(f"  seq_length:  {config_data['seq_length']}")
    print(f"  batch_size:  {config_data['batch_size_per_gpu']}")
    print(f"  grad_accum:  {config_data['gradient_accumulation']}")

    world_size = hw.gpu_count if hw.device_type == "cuda" and hw.gpu_count > 0 else 1
    effective = (
        config_data["batch_size_per_gpu"]
        * world_size
        * config_data["gradient_accumulation"]
    )
    print(f"  effective_batch: {effective}")
    print(f"  learning_rate:   {config_data['learning_rate']}")
    print(f"  dropout:     {config_data['dropout']}")
    print(f"  epochs:      {config_data['epochs']}")
    print(f"  use_compile: {config_data['use_compile']}")
    print(f"\n{'=' * 60}")


def validate_config(config_data: dict) -> TrainingConfig:
    """Validate by constructing a TrainingConfig from the generated data."""
    clean = {k: v for k, v in config_data.items() if not k.startswith("_")}
    return TrainingConfig(**clean)


def autotune(
    midi_dir: str | None = None,
    cache_path: str | None = None,
    output_path: str | None = None,
    vocab_size: int = 2000,
    quiet: bool = False,
) -> dict:
    """Detect hardware, analyze dataset, and generate an optimized config.

    Args:
        midi_dir: Path to directory containing MIDI files.
        cache_path: Path to existing token_cache.pkl for precise analysis.
        output_path: Path to write the JSON config (None = don't write).
        vocab_size: Approximate vocab size for memory estimation.
        quiet: Suppress stdout output.

    Returns:
        The complete config dict including metadata fields.
    """
    hw = detect_hardware()
    ds = analyze_dataset(midi_dir=midi_dir, cache_path=cache_path)
    config_data = generate_config(hw, ds, vocab_size=vocab_size)

    # Validate round-trip through TrainingConfig
    validate_config(config_data)

    output = build_output_dict(config_data, hw, ds)

    if not quiet:
        print_summary(config_data, hw, ds)

    if output_path:
        Path(output_path).parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, "w") as f:
            json.dump(output, f, indent=4)
        if not quiet:
            print(f"\nConfig written to: {output_path}")

    return output


def main():
    parser = argparse.ArgumentParser(
        description="Auto-tune training configuration based on hardware and dataset"
    )
    parser.add_argument(
        "--midi-dir",
        type=str,
        default=None,
        help="Directory containing .mid/.midi files",
    )
    parser.add_argument(
        "--cache",
        type=str,
        default=None,
        help="Path to existing token_cache.pkl for precise dataset analysis",
    )
    parser.add_argument(
        "--output",
        type=str,
        default="configs/auto.json",
        help="Output path for generated config (default: configs/auto.json)",
    )
    parser.add_argument(
        "--vocab-size",
        type=int,
        default=2000,
        help="Approximate vocabulary size for memory estimation (default: 2000)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print config without writing to file",
    )
    args = parser.parse_args()

    if args.midi_dir is None and args.cache is None:
        parser.error("At least one of --midi-dir or --cache is required")

    output_path = None if args.dry_run else args.output
    autotune(
        midi_dir=args.midi_dir,
        cache_path=args.cache,
        output_path=output_path,
        vocab_size=args.vocab_size,
    )


if __name__ == "__main__":
    main()
