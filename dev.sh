#!/usr/bin/env bash
# studio///diskrot — Rebuild backend + UI from source (macOS / Linux / Git Bash)
#
# Builds only studio-backend and studio-ui, then starts the full stack.
# For all images (including acestep + yulan), use ./dev-all.sh instead.
#
# Usage:
#   ./dev.sh              Build backend + UI and start the stack
#   ./dev.sh --no-cache   Rebuild without Docker layer cache
#
# All flags from dev-all.sh are supported (--no-cache, --build-only, --gpu, --cpu).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/dev-all.sh" "$@" studio-backend studio-ui
