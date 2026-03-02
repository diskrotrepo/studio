# ==============================================================
# Bark TTS — Multi-platform Dockerfile
#
# Serves Suno Bark text-to-speech via a FastAPI server.
#
# Usage:
#   Mac (Apple Silicon, CPU-only):
#     docker build --build-arg VARIANT=cpu -t bark .
#
#   Linux/Windows (NVIDIA GPU):
#     docker build -t bark .
# ==============================================================

ARG VARIANT=cuda

# ---- CUDA base stage ----
FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04 AS base-cuda

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        python3.11 python3.11-venv python3.11-dev python3-pip \
        curl ca-certificates ffmpeg libsndfile1 gcc \
    && ln -sf /usr/bin/python3.11 /usr/bin/python \
    && ln -sf /usr/bin/python3.11 /usr/bin/python3 \
    && rm -rf /var/lib/apt/lists/*

RUN python -m pip install --no-cache-dir --upgrade pip setuptools wheel

# PyTorch + CUDA 12.8
RUN pip install --no-cache-dir \
    torch torchvision torchaudio \
    --extra-index-url https://download.pytorch.org/whl/cu128

# ---- CPU base stage (Mac / ARM) ----
FROM python:3.11-slim AS base-cpu

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates ffmpeg libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

RUN python -m pip install --no-cache-dir --upgrade pip setuptools wheel

# PyTorch CPU-only
RUN pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# ---- Common build (selected by VARIANT) ----
FROM base-${VARIANT} AS runtime

WORKDIR /app

# Install Python deps (cached layer — changes rarely)
RUN pip install --no-cache-dir \
    encodec \
    funcy \
    "huggingface-hub>=0.14.1" \
    numpy \
    scipy \
    tokenizers \
    transformers \
    tqdm \
    boto3 \
    fastapi \
    "uvicorn[standard]"

# Copy source
COPY . /app

# Install bark package
RUN pip install --no-cache-dir --no-deps -e /app

# Runtime environment
ENV BARK_PORT=8002 \
    BARK_OUTPUT_DIR=/data/output \
    BARK_HF_REPO=diskrot/bark-diskrot \
    SUNO_USE_SMALL_MODELS=False \
    SUNO_OFFLOAD_CPU=False \
    TORCHDYNAMO_DISABLE=1

RUN useradd -r -u 1001 -g root -d /app -s /sbin/nologin appuser \
    && mkdir -p /data/output \
    && chown -R appuser:root /app /data/output \
    && chmod -R g+w /app /data/output

COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh

USER 1001

EXPOSE 8002

ENTRYPOINT ["entrypoint.sh"]
CMD ["python", "api_server.py"]
