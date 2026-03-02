#!/bin/sh
# Ensure bind-mounted directories are writable.
mkdir -p /data/output 2>/dev/null || true

exec "$@"
