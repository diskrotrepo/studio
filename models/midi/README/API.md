# API Server

## Setup

Start Redis (needed for Celery task queue):

```bash
docker run -d -p 6379:6379 redis:latest
```

Run the Django dev server:

```bash
python manage.py runserver
```

In a separate terminal, start the Celery worker:

```bash
celery -A midi_api worker --loglevel=info
```

A model checkpoint is required at `checkpoints/best_model.pt` (or set `MIDI_CHECKPOINT` env var).

## Endpoints

The API is available at `http://localhost:8000/api/`.

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/health/` | GET | Health check |
| `/api/tags/` | GET | List available tags |
| `/api/generate/` | POST | Generate single-track MIDI |
| `/api/generate/multitrack/` | POST | Generate multi-track MIDI |
| `/api/tasks/{task_id}/` | GET | Check async task status |
| `/api/download/{file_id}/` | GET | Download generated file |
