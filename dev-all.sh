#!/usr/bin/env bash
# studio///diskrot — Build ALL images from source (macOS / Linux / Git Bash)
#
# Builds every custom Docker image from local source and starts the stack.
# For backend + UI only, use ./dev.sh instead.
#
# Usage:
#   ./dev-all.sh                      Build all images and start the stack
#   ./dev-all.sh --no-cache           Rebuild without Docker layer cache
#   ./dev-all.sh --build-only         Build images without starting services
#   ./dev-all.sh studio-backend       Build & start only named service(s)
#
# Flags:
#   --no-cache      Pass --no-cache to docker compose build
#   --build-only    Build images and exit (don't start services)
#   --gpu           Force GPU compose overlay (auto-detected from .env)
#   --cpu           Skip GPU compose overlay even if .env enables it

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── Parse arguments ──────────────────────────────────────────────────
NO_CACHE=""
BUILD_ONLY=false
FORCE_GPU=""
SERVICES=()

for arg in "$@"; do
  case "$arg" in
    --no-cache)   NO_CACHE="--no-cache" ;;
    --build-only) BUILD_ONLY=true ;;
    --gpu)        FORCE_GPU=yes ;;
    --cpu)        FORCE_GPU=no ;;
    -h|--help)
      sed -n '2,/^$/s/^# \?//p' "$0"
      exit 0
      ;;
    *)            SERVICES+=("$arg") ;;
  esac
done

# ── Compose file list ────────────────────────────────────────────────
COMPOSE_FILES=("-f" "docker-compose.yml" "-f" "docker-compose.dev.yml")

use_gpu=false
if [ "$FORCE_GPU" = "yes" ]; then
  use_gpu=true
elif [ "$FORCE_GPU" != "no" ] && [ -f .env ]; then
  # Auto-detect: if .env references the gpu overlay, include it
  if grep -qE 'docker-compose\.gpu\.yml' .env 2>/dev/null; then
    use_gpu=true
  fi
fi

if [ "$use_gpu" = true ] && [ -f docker-compose.gpu.yml ]; then
  COMPOSE_FILES+=("-f" "docker-compose.gpu.yml")
  echo "[dev] GPU overlay enabled"
fi

# ── Export build metadata ────────────────────────────────────────────
export BUILD_DATE
BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
export BUILD_BRANCH
BUILD_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo dev)"

# ── Build ────────────────────────────────────────────────────────────
echo "[dev] Building images locally..."
if [ ${#SERVICES[@]} -gt 0 ]; then
  echo "[dev] Services: ${SERVICES[*]}"
fi

docker compose "${COMPOSE_FILES[@]}" build $NO_CACHE "${SERVICES[@]}"

if [ "$BUILD_ONLY" = true ]; then
  echo "[dev] Build complete."
  exit 0
fi

# ── Start ────────────────────────────────────────────────────────────
echo "[dev] Starting stack..."
docker compose "${COMPOSE_FILES[@]}" up -d "${SERVICES[@]}"

# shellcheck disable=SC2016
UI_PORT=$(grep -oP 'UI_PORT=\K[0-9]+' .env 2>/dev/null || echo 3000)
echo "[dev] Stack is up.  UI → http://localhost:${UI_PORT}"
