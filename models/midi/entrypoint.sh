#!/bin/bash
set -e

# Start Celery worker in background
celery -A midi_api worker --loglevel=info --concurrency=2 &

# Start gunicorn
exec gunicorn midi_api.wsgi:application \
    --bind 0.0.0.0:${PORT:-8080} \
    --workers 2 \
    --timeout 600 \
    --access-logfile - \
    --error-logfile -
