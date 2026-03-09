# ==============================================================
# LTX-2 Audio — Multi-platform Dockerfile
#
# Usage:
#   Linux/Windows (NVIDIA GPU):
#     docker build -t ltx .
#
#   Mac (Apple Silicon, CPU-only):
#     docker build --build-arg VARIANT=cpu -t ltx .
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
RUN pip install --no-cache-dir torch torchaudio --index-url https://download.pytorch.org/whl/cpu

# ---- Common build (selected by VARIANT) ----
FROM base-${VARIANT} AS runtime

WORKDIR /app

# ---- Install dependencies BEFORE copying source (cache-friendly) ----
RUN pip install --no-cache-dir \
    safetensors \
    "transformers>=4.52" \
    "scipy>=1.14" \
    einops \
    numpy \
    accelerate \
    av \
    tqdm \
    pillow \
    "fastapi>=0.110.0" \
    "uvicorn[standard]>=0.27.0" \
    huggingface_hub

# ---- Copy source and install packages ----
COPY . /app

# Install ltx-core and ltx-pipelines as editable (no-deps to avoid re-resolving torch)
RUN pip install --no-cache-dir --no-deps -e /app/packages/ltx-core \
    && pip install --no-cache-dir --no-deps -e /app/packages/ltx-pipelines

# Runtime environment
ENV LTX_CHECKPOINT_PATH=/app/checkpoints \
    LTX_GEMMA_ROOT=/app/checkpoints/gemma \
    LTX_OUTPUT_DIR=/data/output \
    LTX_LORA_DIR=/app/loras \
    LTX_API_HOST=0.0.0.0 \
    LTX_API_PORT=8005 \
    LTX_API_KEY=

# Device: cuda for GPU, cpu for Mac
ARG VARIANT
ENV LTX_DEVICE=${VARIANT}

RUN useradd -r -u 1001 -g root -d /app -s /sbin/nologin appuser \
    && mkdir -p /data/output /app/checkpoints /app/loras \
    && chown -R appuser:root /app /data/output \
    && chmod -R g+w /app /data/output

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER 1001

EXPOSE 8005

ENTRYPOINT ["entrypoint.sh"]
CMD ["python", "/app/api_server.py", "--host", "0.0.0.0", "--port", "8005"]
