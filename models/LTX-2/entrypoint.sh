#!/bin/sh
# Ensure bind-mounted directories are writable.
mkdir -p /app/checkpoints /app/loras /data/output 2>/dev/null || true

exec "$@"
