#!/bin/sh
set -e

HF_MODEL="${HF_MODEL:-diskrot/YuLan-Mini-GGUF-diskrot}"
GGUF_DIR="${GGUF_DIR:-/data/gguf}"
PORT="${YULAN_PORT:-8003}"
CTX_SIZE="${YULAN_CTX_SIZE:-4096}"
THREADS="${YULAN_THREADS:-4}"
GPU_LAYERS="${YULAN_GPU_LAYERS:-999}"

# ── Find existing GGUF file ──
GGUF_FILE=""
if [ -d "$GGUF_DIR" ]; then
    GGUF_FILE=$(find "$GGUF_DIR" -maxdepth 2 -name '*.gguf' -type f 2>/dev/null | head -1)
fi

# ── Download if not cached ──
if [ -z "$GGUF_FILE" ]; then
    echo "[llama.cpp] No GGUF model found. Downloading from ${HF_MODEL}..."
    python3 -c "
from huggingface_hub import snapshot_download
path = snapshot_download('${HF_MODEL}', cache_dir='${HF_HOME:-/data/hf-cache}', local_dir='${GGUF_DIR}/model')
print(f'[llama.cpp] Downloaded to: {path}')
"
    GGUF_FILE=$(find "$GGUF_DIR" -maxdepth 2 -name '*.gguf' -type f 2>/dev/null | head -1)

    if [ -z "$GGUF_FILE" ]; then
        echo "[llama.cpp] ERROR: No .gguf file found after download. Check the HF_MODEL repo."
        exit 1
    fi
fi

echo "[llama.cpp] Using model: $GGUF_FILE"

# ── Build GPU layers flag if set ──
NGL_FLAG=""
if [ "$GPU_LAYERS" != "0" ] && [ "$GPU_LAYERS" != "" ]; then
    NGL_FLAG="--n-gpu-layers $GPU_LAYERS"
fi

# ── Start llama-server ──
echo "[llama.cpp] Starting llama-server on port $PORT (ctx=$CTX_SIZE, threads=$THREADS, gpu_layers=$GPU_LAYERS)..."
exec llama-server \
    --model "$GGUF_FILE" \
    --host 0.0.0.0 \
    --port "$PORT" \
    --ctx-size "$CTX_SIZE" \
    --threads "$THREADS" \
    $NGL_FLAG \
    --jinja
