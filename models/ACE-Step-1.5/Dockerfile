# ==============================================================
# ACE-Step 1.5 — Multi-platform Dockerfile
#
# Usage:
#   Linux/Windows (NVIDIA GPU):
#     docker build -t ace-step .
#
#   Mac (Apple Silicon, CPU-only):
#     docker build --build-arg VARIANT=cpu -t ace-step .
# ==============================================================

ARG VARIANT=cuda

# ---- CUDA base stage ----
FROM nvidia/cuda:12.8.0-devel-ubuntu22.04 AS base-cuda

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        git ffmpeg libsndfile1 curl \
        python3.11 python3.11-venv python3.11-dev python3-pip \
    && ln -sf /usr/bin/python3.11 /usr/bin/python \
    && ln -sf /usr/bin/python3.11 /usr/bin/python3 \
    && rm -rf /var/lib/apt/lists/*

RUN python -m pip install --no-cache-dir --upgrade pip setuptools wheel

# PyTorch + CUDA 12.8
RUN pip install --no-cache-dir \
    torch==2.10.0+cu128 \
    torchvision==0.25.0+cu128 \
    torchaudio==2.10.0+cu128 \
    --extra-index-url https://download.pytorch.org/whl/cu128

# ---- CPU base stage (Mac / ARM) ----
FROM python:3.11-slim AS base-cpu

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        git ffmpeg libsndfile1 curl \
    && rm -rf /var/lib/apt/lists/*

RUN python -m pip install --no-cache-dir --upgrade pip setuptools wheel

# PyTorch CPU-only
RUN pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# ---- Common build (selected by VARIANT) ----
FROM base-${VARIANT} AS runtime

WORKDIR /app

# ---- Install dependencies BEFORE copying source (cache-friendly) ----

# Remaining deps (shared across both variants)
RUN pip install --no-cache-dir \
    safetensors==0.7.0 \
    "transformers>=4.51.0,<4.58.0" \
    "diffusers @ git+https://github.com/huggingface/diffusers@main" \
    "scipy>=1.10.1" \
    "soundfile>=0.13.1" \
    "loguru>=0.7.3" \
    "einops>=0.8.1" \
    "accelerate>=1.12.0" \
    "fastapi>=0.110.0" \
    "uvicorn[standard]>=0.27.0" \
    "numba>=0.63.1" \
    "vector-quantize-pytorch>=1.27.15" \
    "torchcodec>=0.9.1; platform_machine != 'aarch64'" \
    "torchao>=0.14.1,<0.16.0; platform_machine != 'aarch64'" \
    "torchao; platform_machine == 'aarch64'" \
    toml \
    modelscope \
    "peft>=0.18.0" \
    lycoris-lora \
    "lightning>=2.0.0" \
    "tensorboard>=2.20.0" \
    "typer-slim>=0.21.1" \
    "matplotlib>=3.7.5" \
    diskcache \
    xxhash \
    huggingface_hub \
    python-dotenv \
    "gradio==6.2.0"


# Triton is CUDA-only — install conditionally
ARG VARIANT
RUN if [ "$VARIANT" = "cuda" ]; then \
        pip install --no-cache-dir "triton>=3.0.0" \
        && python -c 'import triton; import torch; print("triton+torch imported")'; \
    else \
        python -c 'import torch; print("torch CPU imported, version:", torch.__version__)'; \
    fi

# ---- Now copy source and install project (fast, changes often) ----
COPY . /app

# Install vendored nano-vllm and the project itself
# --no-deps avoids re-resolving torch from pyproject.toml platform markers
RUN pip install --no-cache-dir --no-deps -e /app/acestep/third_parts/nano-vllm \
    && pip install --no-cache-dir --no-deps -e /app

# Runtime environment
ENV ACESTEP_CONFIG_PATH=acestep-v15-turbo \
    ACESTEP_LM_MODEL_PATH=acestep-5Hz-lm-1.7B \
    ACESTEP_LM_BACKEND=vllm \
    ACESTEP_INIT_LLM=true \
    ACESTEP_DOWNLOAD_SOURCE=huggingface \
    ACESTEP_API_HOST=0.0.0.0 \
    ACESTEP_API_PORT=8001 \
    ACESTEP_NO_INIT=false \
    ACESTEP_COMPILE_MODEL=false \
    ACESTEP_USE_FLASH_ATTENTION=false \
    ACESTEP_TMPDIR=/data/output

# Device: cuda for GPU, cpu for Mac
ARG VARIANT
ENV ACESTEP_DEVICE=${VARIANT}

RUN useradd -r -u 1001 -g root -d /app -s /sbin/nologin appuser \
    && mkdir -p /data/output /app/checkpoints \
    && chown -R appuser:root /app /data/output \
    && chmod -R g+w /app /data/output

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER 1001

EXPOSE 8001

ENTRYPOINT ["entrypoint.sh"]
CMD ["python", "-m", "acestep.api_server", "--host", "0.0.0.0", "--port", "8001"]
