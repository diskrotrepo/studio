"""
Django settings for MIDI API project.
"""

import os
from pathlib import Path

# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = os.environ["DJANGO_SECRET_KEY"]

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = os.environ.get("DJANGO_DEBUG", "True").lower() == "true"

ALLOWED_HOSTS = os.environ.get("DJANGO_ALLOWED_HOSTS", "localhost,127.0.0.1").split(",")

# Application definition
INSTALLED_APPS = [
    "daphne",
    "django.contrib.contenttypes",
    "django.contrib.staticfiles",
    "corsheaders",
    "rest_framework",
    "channels",
    "api",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.common.CommonMiddleware",
]

# CORS - allow Flutter web dev server
CORS_ALLOWED_ORIGIN_REGEXES = [
    r"^http://localhost:\d+$",
    r"^http://127\.0\.0\.1:\d+$",
]

ROOT_URLCONF = "midi_api.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
            ],
        },
    },
]

WSGI_APPLICATION = "midi_api.wsgi.application"
ASGI_APPLICATION = "midi_api.asgi.application"

# Database - not needed for this API, but Django requires it
DATABASES = {}

# Internationalization
LANGUAGE_CODE = "en-us"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True

# Static files (CSS, JavaScript, Images)
STATIC_URL = "static/"

# Default primary key field type
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# REST Framework settings
REST_FRAMEWORK = {
    "DEFAULT_RENDERER_CLASSES": [
        "rest_framework.renderers.JSONRenderer",
    ],
    "DEFAULT_PARSER_CLASSES": [
        "rest_framework.parsers.JSONParser",
        "rest_framework.parsers.MultiPartParser",
        "rest_framework.parsers.FormParser",
    ],
    "EXCEPTION_HANDLER": "rest_framework.views.exception_handler",
    "UNAUTHENTICATED_USER": None,
    "UNAUTHENTICATED_TOKEN": None,
    "DEFAULT_AUTHENTICATION_CLASSES": [],
}

# =============================================================================
# MIDI Generation Settings
# =============================================================================

# Base directory for model folders. Each model lives in a subdirectory
# named after it, containing a checkpoint (.pt) and tokenizer.json.
#
# Example layout:
#   checkpoints/
#     default/
#       best_model.pt
#       tokenizer.json
#     jazz/
#       best_model.pt
#       tokenizer.json
MIDI_MODELS_DIR = Path(os.environ.get(
    "MIDI_MODELS_DIR", str(BASE_DIR / "checkpoints")
))

# Per-model overrides (optional). Models are auto-discovered from
# subdirectories of MIDI_MODELS_DIR. Use this dict to specify LoRA
# adapters or other per-model config.
#
# Example:
# MIDI_MODELS = {
#     "jazz": {"lora_adapter": "/path/to/jazz_lora.pt"},
# }
MIDI_MODELS = {}

# Device for inference: 'auto', 'cpu', 'cuda', 'mps'
MIDI_DEVICE = os.environ.get("MIDI_DEVICE", "auto")

# Directory for generated files
GENERATED_FILES_DIR = Path(
    os.environ.get("MIDI_GENERATED_DIR", str(BASE_DIR / "generated"))
)
GENERATED_FILES_DIR.mkdir(exist_ok=True)

# How long to keep generated files (in hours)
FILE_EXPIRY_HOURS = int(os.environ.get("FILE_EXPIRY_HOURS", "1"))

# Path to SoundFont for MP3 conversion (optional)
MIDI_SOUNDFONT = os.environ.get("MIDI_SOUNDFONT", None)

# =============================================================================
# Celery Settings
# =============================================================================

CELERY_BROKER_URL = os.environ.get("REDIS_URL", "redis://localhost:6379/0")
CELERY_RESULT_BACKEND = CELERY_BROKER_URL
CELERY_ACCEPT_CONTENT = ["json"]
CELERY_TASK_SERIALIZER = "json"
CELERY_RESULT_SERIALIZER = "json"
CELERY_TIMEZONE = TIME_ZONE
CELERY_TASK_TRACK_STARTED = True
CELERY_TASK_TIME_LIMIT = 600  # 10 minutes max per task
CELERY_WORKER_POOL = os.environ.get("CELERY_WORKER_POOL", "threads")
CELERY_WORKER_CONCURRENCY = int(os.environ.get("CELERY_WORKER_CONCURRENCY", 6))

# =============================================================================
# Django Channels Settings
# =============================================================================

CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels_redis.core.RedisChannelLayer",
        "CONFIG": {
            "hosts": [CELERY_BROKER_URL],
        },
    },
}

# =============================================================================
# GCS Storage Settings
# =============================================================================

DISKROT_AUDIO_BUCKET = os.environ.get("DISKROT_AUDIO_BUCKET", "diskrot_audio")
GCS_MIDI_PREFIX = os.environ.get("GCS_MIDI_PREFIX", "midi")
