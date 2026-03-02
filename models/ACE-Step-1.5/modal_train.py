"""Modal training for ACE-Step 1.5 LoRA fine-tuning on A100.

Runs the full pipeline on Modal GPUs:
  1. Preprocess: audio + lyrics + annotations → .pt tensors
  2. Train: LoRA fine-tuning on preprocessed tensors
  3. Download: retrieve trained LoRA weights

Setup:
    # Create a Modal volume for persistent training data
    modal volume create acestep-training

    # Upload your dataset (audio files + .lyrics.txt + optional .json annotations)
    modal volume put acestep-training ./my_dataset /dataset

Usage:
    # Run full pipeline (preprocess + train)
    modal run modal_train.py

    # Preprocess only
    modal run modal_train.py::preprocess

    # Train only (if tensors already exist on the volume)
    modal run modal_train.py::train

    # Download trained LoRA weights
    modal volume get acestep-training /lora_output ./my_lora_weights

Customize training:
    modal run modal_train.py --epochs 500 --batch-size 2 --lr 1e-4
"""

from __future__ import annotations

import modal

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

REPO_ID = "ACE-Step/Ace-Step1.5"
MODEL_DIR = "/app/checkpoints"
GPU = "A100-40GB"

app = modal.App("acestep-train")

# Persistent volume for dataset, tensors, and output LoRA weights.
# Data survives across function calls and can be accessed via `modal volume`.
training_vol = modal.Volume.from_name("acestep-training", create_if_missing=True)

VOLUME_MOUNT = "/data"


# ---------------------------------------------------------------------------
# Container image (shared by preprocess + train)
# ---------------------------------------------------------------------------

def _download_models():
    """Download model weights at image build time — baked into the layer."""
    from huggingface_hub import snapshot_download

    snapshot_download(
        repo_id=REPO_ID,
        local_dir=MODEL_DIR,
        local_dir_use_symlinks=False,
    )


image = (
    modal.Image.from_registry(
        "nvidia/cuda:12.8.0-devel-ubuntu22.04",
        add_python="3.11",
    )
    .apt_install("git", "ffmpeg", "libsndfile1")
    .pip_install(
        "torch==2.10.0+cu128",
        "torchaudio==2.10.0+cu128",
        extra_index_url="https://download.pytorch.org/whl/cu128",
    )
    .pip_install(
        # Core ML
        "safetensors==0.7.0",
        "transformers>=4.51.0,<4.58.0",
        "diffusers",
        "scipy>=1.10.1",
        "soundfile>=0.13.1",
        "einops>=0.8.1",
        "accelerate>=1.12.0",
        "numba>=0.63.1",
        "vector-quantize-pytorch>=1.27.15",
        "torchcodec>=0.9.1",
        "torchao>=0.14.1,<0.16.0",
        # Training
        "peft>=0.18.0",
        "lycoris-lora",
        "lightning>=2.0.0",
        "tensorboard>=2.20.0",
        # Utilities
        "loguru>=0.7.3",
        "typer-slim>=0.21.1",
        "toml",
        "modelscope",
        "huggingface_hub",
        "diskcache",
        "xxhash",
        "triton>=3.0.0",
        # Gradio (needed due to import chains in ACE-Step)
        "gradio==6.2.0",
    )
    .add_local_dir(
        ".",
        remote_path="/app",
        copy=True,
        ignore=[
            ".git",
            "__pycache__",
            "*.pyc",
            ".DS_Store",
            "checkpoints",
            ".cache",
            "*.log",
            ".venv",
            "venv",
        ],
    )
    .run_commands(
        "pip install -e /app/acestep/third_parts/nano-vllm",
        "pip install -e /app --extra-index-url https://download.pytorch.org/whl/cu128",
    )
    # Bake model weights into image layer (cached after first build)
    .run_function(_download_models)
    # Pre-warm Triton cache
    .run_commands(
        "python -c 'import triton; import torch; print(\"triton+torch OK\")'",
    )
)


# ---------------------------------------------------------------------------
# Preprocessing function
# ---------------------------------------------------------------------------

@app.function(
    image=image,
    gpu=GPU,
    volumes={VOLUME_MOUNT: training_vol},
    timeout=3600,
)
def preprocess(
    dataset_dir: str = "/data/dataset",
    dataset_json: str = "",
    tensor_output: str = "/data/tensors",
    model_variant: str = "turbo",
    max_duration: float = 240.0,
):
    """Convert audio files to preprocessed .pt tensors (two-pass pipeline).

    Args:
        dataset_dir: Path to audio files on the volume.
        dataset_json: Optional path to labeled dataset JSON (overrides dataset_dir scan).
        tensor_output: Where to write .pt files on the volume.
        model_variant: Model variant — turbo, base, or sft.
        max_duration: Maximum audio duration in seconds.
    """
    import torch
    from acestep.training_v2.preprocess import preprocess_audio_files

    torch.set_float32_matmul_precision("medium")

    print("=" * 60)
    print("  ACE-Step Preprocessing (Modal)")
    print("=" * 60)
    print(f"  Source:      {dataset_json or dataset_dir}")
    print(f"  Output:      {tensor_output}")
    print(f"  Checkpoint:  {MODEL_DIR}")
    print(f"  Variant:     {model_variant}")
    print(f"  Max dur:     {max_duration}s")
    print("=" * 60)

    result = preprocess_audio_files(
        audio_dir=dataset_dir if not dataset_json else None,
        output_dir=tensor_output,
        checkpoint_dir=MODEL_DIR,
        variant=model_variant,
        max_duration=max_duration,
        dataset_json=dataset_json or None,
        device="cuda",
        precision="auto",
    )

    print(f"\nPreprocessing complete:")
    print(f"  Processed: {result['processed']}/{result['total']}")
    if result["failed"]:
        print(f"  Failed:    {result['failed']}")
    print(f"  Output:    {result['output_dir']}")

    # Persist to volume
    training_vol.commit()
    return result


# ---------------------------------------------------------------------------
# Training function
# ---------------------------------------------------------------------------

@app.function(
    image=image,
    gpu=GPU,
    volumes={VOLUME_MOUNT: training_vol},
    timeout=14400,  # 4 hours max
)
def train(
    dataset_dir: str = "/data/tensors",
    output_dir: str = "/data/lora_output",
    model_variant: str = "turbo",
    epochs: int = 500,
    batch_size: int = 2,
    lr: float = 1e-4,
    gradient_accumulation: int = 4,
    rank: int = 64,
    alpha: int = 128,
    save_every: int = 50,
    adapter_type: str = "lora",
    warmup_steps: int = 100,
    seed: int = 42,
):
    """Run LoRA/LoKR fine-tuning on preprocessed tensors.

    Args:
        dataset_dir: Path to preprocessed .pt tensors on the volume.
        output_dir: Where to save LoRA weights on the volume.
        model_variant: Model variant — turbo, base, or sft.
        epochs: Maximum training epochs.
        batch_size: Training batch size (2-4 on A100-40GB).
        lr: Learning rate.
        gradient_accumulation: Gradient accumulation steps.
        rank: LoRA rank.
        alpha: LoRA alpha.
        save_every: Save checkpoint every N epochs.
        adapter_type: Adapter type — lora or lokr.
        warmup_steps: LR warmup steps.
        seed: Random seed.
    """
    import subprocess

    cmd = [
        "python", "/app/train.py",
        "--plain", "--yes",
        "fixed",
        "--checkpoint-dir", MODEL_DIR,
        "--model-variant", model_variant,
        "--dataset-dir", dataset_dir,
        "--output-dir", output_dir,
        "--device", "cuda",
        "--precision", "auto",
        "--epochs", str(epochs),
        "--batch-size", str(batch_size),
        "--lr", str(lr),
        "--gradient-accumulation", str(gradient_accumulation),
        "--warmup-steps", str(warmup_steps),
        "--seed", str(seed),
        "--save-every", str(save_every),
        "--adapter-type", adapter_type,
        "--rank", str(rank),
        "--alpha", str(alpha),
        "--gradient-checkpointing",
        "--log-dir", f"{output_dir}/runs",
    ]

    print("=" * 60)
    print("  ACE-Step LoRA Training (Modal)")
    print("=" * 60)
    print(f"  Dataset:     {dataset_dir}")
    print(f"  Output:      {output_dir}")
    print(f"  Variant:     {model_variant}")
    print(f"  Adapter:     {adapter_type}")
    print(f"  Epochs:      {epochs}")
    print(f"  Batch size:  {batch_size}")
    print(f"  LR:          {lr}")
    print(f"  Rank:        {rank}")
    print(f"  Alpha:       {alpha}")
    print("=" * 60)
    print(f"\n  Command: {' '.join(cmd)}\n")

    # Stream output in real time
    proc = subprocess.Popen(
        cmd,
        cwd="/app",
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )

    for line in proc.stdout:
        print(line, end="")

    proc.wait()

    if proc.returncode != 0:
        raise RuntimeError(f"Training exited with code {proc.returncode}")

    # Persist outputs to volume
    training_vol.commit()

    print("\n" + "=" * 60)
    print(f"  Training complete! LoRA weights saved to {output_dir}")
    print(f"  Download with: modal volume get acestep-training /lora_output ./my_lora")
    print("=" * 60)


# ---------------------------------------------------------------------------
# Local entrypoint — runs the full pipeline
# ---------------------------------------------------------------------------

@app.local_entrypoint()
def main(
    # Dataset paths
    dataset_dir: str = "/data/dataset",
    dataset_json: str = "",
    tensor_output: str = "/data/tensors",
    output_dir: str = "/data/lora_output",
    # Model
    model_variant: str = "turbo",
    # Preprocessing
    max_duration: float = 240.0,
    skip_preprocess: bool = False,
    # Training
    epochs: int = 500,
    batch_size: int = 2,
    lr: float = 1e-4,
    gradient_accumulation: int = 4,
    rank: int = 64,
    alpha: int = 128,
    save_every: int = 50,
    adapter_type: str = "lora",
    warmup_steps: int = 100,
    seed: int = 42,
    skip_train: bool = False,
):
    """Run the full ACE-Step LoRA training pipeline on Modal.

    Steps:
      1. Preprocess audio → tensors (skipped with --skip-preprocess)
      2. Train LoRA adapter (skipped with --skip-train)
    """
    if not skip_preprocess:
        print("Step 1/2: Preprocessing...")
        result = preprocess.remote(
            dataset_dir=dataset_dir,
            dataset_json=dataset_json,
            tensor_output=tensor_output,
            model_variant=model_variant,
            max_duration=max_duration,
        )
        print(f"  Preprocessed {result['processed']}/{result['total']} files\n")
    else:
        print("Step 1/2: Preprocessing (skipped)\n")

    if not skip_train:
        print("Step 2/2: Training...")
        train.remote(
            dataset_dir=tensor_output,
            output_dir=output_dir,
            model_variant=model_variant,
            epochs=epochs,
            batch_size=batch_size,
            lr=lr,
            gradient_accumulation=gradient_accumulation,
            rank=rank,
            alpha=alpha,
            save_every=save_every,
            adapter_type=adapter_type,
            warmup_steps=warmup_steps,
            seed=seed,
        )
    else:
        print("Step 2/2: Training (skipped)\n")

    print("\nDone! Download your LoRA weights:")
    print(f"  modal volume get acestep-training {output_dir} ./my_lora_weights")
