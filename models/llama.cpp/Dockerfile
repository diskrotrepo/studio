# ==============================================================
# llama.cpp — Multi-platform Dockerfile
#
# Serves GGUF models via llama-server (OpenAI-compatible API).
#
# Usage:
#   Mac (Apple Silicon, CPU-only):
#     docker build -t llama-server .
#
#   Linux/Windows (NVIDIA GPU):
#     docker build --build-arg VARIANT=cuda -t llama-server .
# ==============================================================

ARG VARIANT=cpu

# ---- CUDA builder ----
FROM nvidia/cuda:12.8.0-devel-ubuntu22.04 AS builder-cuda

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential cmake git ccache \
    && rm -rf /var/lib/apt/lists/*

COPY vendor /build/llama.cpp

WORKDIR /build/llama.cpp

ENV LIBRARY_PATH=/usr/local/cuda/lib64/stubs
ENV CCACHE_DIR=/ccache
ENV CMAKE_C_COMPILER_LAUNCHER=ccache
ENV CMAKE_CXX_COMPILER_LAUNCHER=ccache
ENV CMAKE_CUDA_COMPILER_LAUNCHER=ccache

RUN --mount=type=cache,target=/ccache \
    cmake -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF \
        -DGGML_CUDA=ON \
        -DCMAKE_CUDA_ARCHITECTURES="86;89;120" \
        -DLLAMA_BUILD_SERVER=ON \
        -DLLAMA_BUILD_TESTS=OFF \
        -DLLAMA_BUILD_EXAMPLES=OFF \
    && cmake --build build --config Release --target llama-server -j$(nproc)

# ---- CPU builder ----
FROM debian:bookworm-slim AS builder-cpu

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential cmake git ccache \
    && rm -rf /var/lib/apt/lists/*

COPY vendor /build/llama.cpp

WORKDIR /build/llama.cpp

ENV CCACHE_DIR=/ccache
ENV CMAKE_C_COMPILER_LAUNCHER=ccache
ENV CMAKE_CXX_COMPILER_LAUNCHER=ccache

RUN --mount=type=cache,target=/ccache \
    cmake -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF \
        -DGGML_NATIVE=OFF \
        -DLLAMA_BUILD_SERVER=ON \
        -DLLAMA_BUILD_TESTS=OFF \
        -DLLAMA_BUILD_EXAMPLES=OFF \
    && cmake --build build --config Release --target llama-server -j$(nproc)

# ---- Resolve builder by VARIANT ----
FROM builder-${VARIANT} AS builder

# ---- CUDA runtime ----
FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04 AS base-cuda

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates python3 python3-pip libgomp1 \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir huggingface_hub

# ---- CPU runtime ----
FROM python:3.11-slim AS base-cpu

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates libgomp1 \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir huggingface_hub

# ---- Common runtime (selected by VARIANT) ----
FROM base-${VARIANT} AS runtime

COPY --from=builder /build/llama.cpp/build/bin/llama-server /usr/local/bin/llama-server

ENV HF_HOME=/data/hf-cache
ENV HF_MODEL=diskrot/YuLan-Mini-GGUF-diskrot
ENV GGUF_DIR=/data/gguf

RUN useradd -r -u 1001 -g root -m -d /home/appuser -s /sbin/nologin appuser \
    && mkdir -p /data/hf-cache /data/gguf \
    && chown -R appuser:root /data/hf-cache /data/gguf \
    && chmod -R g+w /data/hf-cache /data/gguf

COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

USER 1001

EXPOSE 8003

ENTRYPOINT ["entrypoint.sh"]
