#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Activate venv
source venv/bin/activate

# Start Celery worker in background
celery -A midi_api worker --loglevel=info &
CELERY_PID=$!

# Cleanup on exit
trap "kill $CELERY_PID 2>/dev/null; wait $CELERY_PID 2>/dev/null; exit" INT TERM EXIT

# Start Django dev server
python manage.py runserver
