#!/usr/bin/env bash
# studio///diskrot — Start the stack using nightly (dev-channel) images
#
# Pulls and runs images built from the main branch instead of stable.
# Useful for testing the latest changes before they land in a release.
#
# Usage:
#   ./start-nightly.sh              Pull nightly images and start the stack
#   ./start-nightly.sh --gpu        Include GPU compose overlay
#   ./start-nightly.sh --cpu        Skip GPU compose overlay even if .env enables it
#   ./start-nightly.sh --pull-only  Pull images without starting services

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── Banner ───────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo "  studio///diskrot — nightly (dev-channel)"
echo "============================================================"
echo ""

# ── Parse arguments ──────────────────────────────────────────────────
FORCE_GPU=""
PULL_ONLY=false

for arg in "$@"; do
  case "$arg" in
    --gpu)       FORCE_GPU=yes ;;
    --cpu)       FORCE_GPU=no ;;
    --pull-only) PULL_ONLY=true ;;
    -h|--help)
      sed -n '2,/^$/s/^# \?//p' "$0"
      exit 0
      ;;
    *)
      echo "[nightly] Unknown flag: $arg" >&2
      exit 1
      ;;
  esac
done

# ── Compose file list ────────────────────────────────────────────────
COMPOSE_FILES=("-f" "docker-compose.yml" "-f" "docker-compose.nightly.yml")

use_gpu=false
if [ "$FORCE_GPU" = "yes" ]; then
  use_gpu=true
elif [ "$FORCE_GPU" != "no" ] && [ -f .env ]; then
  if grep -qE 'docker-compose\.gpu\.yml' .env 2>/dev/null; then
    use_gpu=true
  fi
fi

if [ "$use_gpu" = true ] && [ -f docker-compose.gpu.yml ]; then
  COMPOSE_FILES+=("-f" "docker-compose.gpu.yml")
  echo "[nightly] GPU overlay enabled"
fi

# ── Pull ─────────────────────────────────────────────────────────────
echo "[nightly] Pulling dev-channel images..."
docker compose "${COMPOSE_FILES[@]}" pull

if [ "$PULL_ONLY" = true ]; then
  echo "[nightly] Pull complete."
  exit 0
fi

# ── Start ────────────────────────────────────────────────────────────
echo "[nightly] Starting stack..."
docker compose "${COMPOSE_FILES[@]}" up -d

# shellcheck disable=SC2016
UI_PORT=$(grep -oP 'UI_PORT=\K[0-9]+' .env 2>/dev/null || echo 3000)
echo "[nightly] Stack is up.  UI -> http://localhost:${UI_PORT}"
