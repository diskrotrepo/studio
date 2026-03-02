#!/bin/sh
# Ensure bind-mounted directories are writable.
# On Windows hosts, Docker Desktop maps UID 1001 correctly, but the
# sub-directories may not exist yet inside the mount.
mkdir -p /app/checkpoints /data/output/api_audio 2>/dev/null || true

exec "$@"
