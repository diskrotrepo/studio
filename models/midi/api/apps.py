"""
Django app configuration with model loading at startup.
"""

import json
import os
import threading
import logging
from pathlib import Path
from django.apps import AppConfig

logger = logging.getLogger(__name__)


class ApiConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'api'

    # Class-level storage: dict of model_name -> loaded resources
    # Each entry: {"model": <Model>, "multitrack_model": <Model|None>,
    #              "tokenizer": <Tokenizer>, "checkpoint": str, "lora_adapter": str|None}
    _models = {}
    _device = None
    _lock = threading.Lock()
    _initialized = False

    def ready(self):
        """Called when Django starts. Load models if this is the main process."""
        # Only load models in the main runserver process, not during migrations
        # RUN_MAIN is set by Django's autoreloader for the child process
        if os.environ.get('RUN_MAIN') == 'true' or os.environ.get('LOAD_MODELS') == 'true':
            self._clear_stale_tasks()
            self._load_models_if_needed()

    @classmethod
    def _clear_stale_tasks(cls):
        """Clear any in-progress generation tasks from a previous server run.

        Purges pending tasks from the Celery broker queue and marks any
        tasks stuck in STARTED state as FAILURE so clients get a clean
        error instead of waiting forever.
        """
        try:
            from midi_api.celery import app as celery_app
            from django.conf import settings
            import redis as redis_lib

            # 1. Purge any pending tasks from the broker queue
            purged = celery_app.control.purge()
            if purged:
                logger.info(f"Purged {purged} pending task(s) from queue")

            # 2. Scan Redis for tasks stuck in STARTED state
            redis_url = getattr(settings, 'CELERY_RESULT_BACKEND', 'redis://localhost:6379/0')
            r = redis_lib.from_url(redis_url)

            cleared = 0
            cursor = 0
            while True:
                cursor, keys = r.scan(cursor, match='celery-task-meta-*', count=100)
                for key in keys:
                    raw = r.get(key)
                    if not raw:
                        continue
                    try:
                        meta = json.loads(raw)
                    except (json.JSONDecodeError, TypeError):
                        continue
                    if meta.get('status') == 'STARTED':
                        meta['status'] = 'FAILURE'
                        meta['result'] = 'Generation cancelled: server was restarted'
                        meta['traceback'] = None
                        r.set(key, json.dumps(meta))
                        cleared += 1
                if cursor == 0:
                    break

            if cleared:
                logger.info(f"Cleared {cleared} stale in-progress task(s)")

        except Exception as e:
            logger.warning(f"Failed to clear stale tasks: {e}")

    @classmethod
    def _get_device(cls):
        """Get the appropriate torch device."""
        import torch
        from django.conf import settings

        device_setting = getattr(settings, 'MIDI_DEVICE', 'auto')

        if device_setting == 'auto':
            if torch.cuda.is_available():
                return torch.device('cuda')
            elif torch.backends.mps.is_available():
                return torch.device('mps')
            return torch.device('cpu')
        else:
            return torch.device(device_setting)

    @classmethod
    def _resolve_model_configs(cls):
        """
        Auto-discover models from subdirectories of MIDI_MODELS_DIR,
        merged with any per-model overrides from MIDI_MODELS.

        Each subdirectory is treated as a model whose name matches
        the folder name.  The folder must contain a checkpoint (.pt)
        and tokenizer.json.
        """
        from django.conf import settings

        models_dir = Path(getattr(settings, 'MIDI_MODELS_DIR', 'checkpoints'))
        overrides = getattr(settings, 'MIDI_MODELS', {})

        configs = {}

        # Auto-discover model folders
        if models_dir.is_dir():
            for subdir in sorted(models_dir.iterdir()):
                if subdir.is_dir():
                    configs[subdir.name] = {
                        "dir": str(subdir),
                        "lora_adapter": None,
                    }

        # Apply per-model overrides (e.g. lora_adapter)
        for name, override in overrides.items():
            if name not in configs:
                configs[name] = {"dir": str(models_dir / name), "lora_adapter": None}
            configs[name].update(override)

        return configs

    @classmethod
    def _find_checkpoint_in_dir(cls, model_dir):
        """Find the best checkpoint file in a model directory.

        Prefers best_model.pt, then the latest checkpoint_epoch_*.pt,
        then a lone .pt file.
        """
        model_dir = Path(model_dir)

        best = model_dir / "best_model.pt"
        if best.exists():
            return best

        epoch_checkpoints = sorted(
            model_dir.glob("checkpoint_epoch_*.pt"),
            key=lambda p: int(p.stem.split("_")[-1]),
        )
        if epoch_checkpoints:
            return epoch_checkpoints[-1]

        pt_files = list(model_dir.glob("*.pt"))
        if len(pt_files) == 1:
            return pt_files[0]

        return None

    @classmethod
    def _load_single_model(cls, name, config):
        """Load a single model from its folder.

        The folder must contain a checkpoint (.pt) and tokenizer.json.
        """
        from midi.generation import load_model

        model_dir = Path(config["dir"])

        # Find checkpoint
        checkpoint_path = cls._find_checkpoint_in_dir(model_dir)
        if checkpoint_path is None:
            raise FileNotFoundError(f"No checkpoint (.pt) found in {model_dir}")

        logger.info(f"[{name}] Loading model from {checkpoint_path}")

        # Require tokenizer in the same folder
        tokenizer_path = model_dir / "tokenizer.json"
        if not tokenizer_path.exists():
            raise FileNotFoundError(
                f"No tokenizer.json found in {model_dir}. "
                f"Each model folder must contain its compatible tokenizer."
            )

        from miditok import REMI
        tokenizer = REMI(params=str(tokenizer_path))
        logger.info(f"[{name}] Loaded tokenizer from {tokenizer_path}")

        lora_path = config.get("lora_adapter")
        model = load_model(
            str(checkpoint_path),
            cls._device,
            lora_adapter_path=lora_path,
        )

        cls._models[name] = {
            "model": model,
            "multitrack_model": None,
            "tokenizer": tokenizer,
            "checkpoint": str(checkpoint_path),
            "lora_adapter": lora_path,
        }

        logger.info(f"[{name}] Model loaded successfully")

    @classmethod
    def _load_models_if_needed(cls):
        """Load all configured models if not already loaded (thread-safe)."""
        if cls._initialized:
            return

        with cls._lock:
            if cls._initialized:
                return

            logger.info("Loading MIDI generation models...")

            cls._device = cls._get_device()
            logger.info(f"Using device: {cls._device}")

            model_configs = cls._resolve_model_configs()

            for name, config in model_configs.items():
                try:
                    cls._load_single_model(name, config)
                except FileNotFoundError as e:
                    logger.warning(f"[{name}] Checkpoint not found: {e}, skipping")
                except Exception as e:
                    logger.exception(f"[{name}] Failed to load: {e}, skipping")

            cls._initialized = True

            if cls._models:
                logger.info(f"Models loaded: {list(cls._models.keys())}")
            else:
                logger.warning("No models loaded. Generation endpoints will be unavailable.")

    @classmethod
    def _load_model_on_demand(cls, model_name):
        """Load a single model on demand if it exists on disk but isn't loaded yet."""
        model_configs = cls._resolve_model_configs()
        config = model_configs.get(model_name)
        if config is None:
            return None

        with cls._lock:
            # Double-check after acquiring lock
            entry = cls._models.get(model_name)
            if entry is not None:
                return entry

            try:
                cls._load_single_model(model_name, config)
                return cls._models[model_name]
            except Exception as e:
                logger.exception(f"[{model_name}] Failed to load on demand: {e}")
                return None

    @classmethod
    def get_model(cls, model_name="default"):
        """Get a loaded model by name, loading on demand if necessary."""
        cls._load_models_if_needed()
        entry = cls._models.get(model_name)
        if entry is not None:
            return entry["model"]

        # Try loading on demand (new model added since startup)
        entry = cls._load_model_on_demand(model_name)
        if entry is not None:
            return entry["model"]

        available = list(cls._models.keys())
        raise ValueError(
            f"Model '{model_name}' not found. Available models: {available}"
        )

    @classmethod
    def get_multitrack_model(cls, model_name="default"):
        """Get a multitrack model by name, lazy-loading if necessary."""
        cls._load_models_if_needed()
        entry = cls._models.get(model_name)
        if entry is None:
            # Try loading on demand
            entry = cls._load_model_on_demand(model_name)
        if entry is None:
            available = list(cls._models.keys())
            raise ValueError(
                f"Model '{model_name}' not found. Available models: {available}"
            )
        if entry["multitrack_model"] is None:
            with cls._lock:
                if entry["multitrack_model"] is None:
                    from midi.generation import load_multitrack_model
                    entry["multitrack_model"] = load_multitrack_model(
                        entry["checkpoint"],
                        cls._device,
                        lora_adapter_path=entry["lora_adapter"],
                    )
                    logger.info(f"[{model_name}] Loaded multitrack model")
        return entry["multitrack_model"]

    @classmethod
    def get_tokenizer(cls, model_name="default"):
        """Get the tokenizer for a specific model."""
        cls._load_models_if_needed()
        entry = cls._models.get(model_name)
        if entry is None:
            # Try loading on demand
            entry = cls._load_model_on_demand(model_name)
        if entry is None:
            available = list(cls._models.keys())
            raise ValueError(
                f"Model '{model_name}' not found. Available models: {available}"
            )
        return entry["tokenizer"]

    @classmethod
    def get_device(cls):
        """Get the torch device."""
        cls._load_models_if_needed()
        return cls._device

    @classmethod
    def get_available_models(cls):
        """Return list of available model names and metadata.

        Re-scans the checkpoints directory each time so new models
        are discovered without a server restart.
        """
        cls._load_models_if_needed()
        model_configs = cls._resolve_model_configs()
        result = []

        for name, config in model_configs.items():
            model_dir = Path(config["dir"])
            checkpoint_path = cls._find_checkpoint_in_dir(model_dir)
            tokenizer_path = model_dir / "tokenizer.json"

            # Only list models that have required files
            if checkpoint_path is None or not tokenizer_path.exists():
                continue

            loaded_entry = cls._models.get(name)
            result.append({
                "name": name,
                "checkpoint": str(checkpoint_path),
                "has_lora": config.get("lora_adapter") is not None,
                "has_multitrack": (
                    loaded_entry["multitrack_model"] is not None
                    if loaded_entry else False
                ),
            })

        return result
