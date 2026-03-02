"""
Modal integration for MIDI music generation.

Deploys inference (T4) and training (A100) to Modal's serverless GPU platform.
Checkpoints and training data are stored in GCS.

Setup:
    modal secret create gcs-credentials GOOGLE_APPLICATION_CREDENTIALS_JSON='{"type":"service_account",...}'

Usage:
    modal run modal_app.py --action generate --tags "jazz happy"
    modal run modal_app.py --action generate --multitrack --num-tracks 4 --tags "rock"
    modal run modal_app.py --action pretokenize
    modal run modal_app.py --action train --epochs 20
    modal run modal_app.py --action train --load-from default --lora --epochs 5
"""

import json
import os
import tempfile
import uuid
from pathlib import Path

import modal

# ---------------------------------------------------------------------------
# App & image
# ---------------------------------------------------------------------------

app = modal.App("midi-music-generation")

GCS_BUCKET = os.environ.get("GCS_BUCKET", "your-training-bucket")
GCS_TRAINING_DATA_BLOB = "midi_files.zip"
GCS_CHECKPOINT_PREFIX = "checkpoints/"
GCS_GENERATED_BUCKET = os.environ.get("GCS_GENERATED_BUCKET", "your-generated-bucket")

GCS_SECRET = modal.Secret.from_name(os.environ.get("GCS_SECRET_NAME", "gcs-credentials"))
API_KEY_SECRET = modal.Secret.from_name(os.environ.get("API_KEY_SECRET_NAME", "api-key"))

checkpoint_volume = modal.Volume.from_name("midi-checkpoints", create_if_missing=True)
VOLUME_CHECKPOINT_DIR = "/vol/checkpoints"
IMAGE_CHECKPOINT_DIR = "/root/checkpoints"

image = (
    modal.Image.debian_slim(python_version="3.11")
    .apt_install("fluidsynth", "ffmpeg")
    .pip_install(
        "torch==2.5.1",
        index_url="https://download.pytorch.org/whl/cu121",
    )
    .pip_install(
        "miditok>=3.0.0",
        "tqdm>=4.65.0",
        "symusic>=0.4.0",
        "google-cloud-storage>=2.14",
        "midi2audio>=0.1.1",
        "pydub>=0.25.1",
    )
    # Install the midi package without pulling deps again
    .add_local_dir("midi", "/root/project/midi", copy=True)
    .add_local_file("pyproject.toml", "/root/project/pyproject.toml", copy=True)
    .add_local_dir("configs", "/root/project/configs", copy=True)
    .run_commands("cd /root/project && pip install --no-deps -e .")
)


def _bake_default_checkpoint():
    """Download the default checkpoint into the image during build."""
    import json
    import os
    from pathlib import Path

    from google.cloud import storage
    from google.oauth2 import service_account

    creds_json = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS_JSON")
    if creds_json:
        info = json.loads(creds_json)
        credentials = service_account.Credentials.from_service_account_info(info)
        client = storage.Client(credentials=credentials)
    else:
        client = storage.Client()

    bucket = client.bucket(os.environ.get("GCS_BUCKET", "your-training-bucket"))
    prefix = "checkpoints/default/"
    local_path = Path("/root/checkpoints/default")
    local_path.mkdir(parents=True, exist_ok=True)

    blobs = list(bucket.list_blobs(prefix=prefix))
    for blob in blobs:
        relative = blob.name[len(prefix):]
        if not relative:
            continue
        dest = local_path / relative
        dest.parent.mkdir(parents=True, exist_ok=True)
        blob.download_to_filename(str(dest))

    print(f"Baked default checkpoint ({len(blobs)} files) into image")


inference_image = image.run_function(_bake_default_checkpoint, secrets=[GCS_SECRET])

# ---------------------------------------------------------------------------
# GCS helpers
# ---------------------------------------------------------------------------


def _get_gcs_client():
    from google.cloud import storage
    from google.oauth2 import service_account

    creds_json = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS_JSON")
    if creds_json:
        info = json.loads(creds_json)
        credentials = service_account.Credentials.from_service_account_info(info)
        return storage.Client(credentials=credentials)
    return storage.Client()


def download_from_gcs(bucket_name: str, blob_name: str, local_path: str):
    client = _get_gcs_client()
    bucket = client.bucket(bucket_name)
    blob = bucket.blob(blob_name)
    Path(local_path).parent.mkdir(parents=True, exist_ok=True)
    blob.download_to_filename(local_path)
    print(f"Downloaded gs://{bucket_name}/{blob_name} -> {local_path}")


def upload_to_gcs(local_path: str, bucket_name: str, blob_name: str):
    client = _get_gcs_client()
    bucket = client.bucket(bucket_name)
    blob = bucket.blob(blob_name)
    blob.upload_from_filename(local_path)
    print(f"Uploaded {local_path} -> gs://{bucket_name}/{blob_name}")


def upload_directory_to_gcs(local_dir: str, bucket_name: str, prefix: str):
    client = _get_gcs_client()
    bucket = client.bucket(bucket_name)
    local_path = Path(local_dir)
    for file_path in local_path.rglob("*"):
        if file_path.is_file():
            blob_name = f"{prefix}{file_path.relative_to(local_path)}"
            blob = bucket.blob(blob_name)
            blob.upload_from_filename(str(file_path))
            print(f"  Uploaded {file_path.name} -> gs://{bucket_name}/{blob_name}")


def download_checkpoint_from_gcs(
    checkpoint_name: str, local_dir: str = "/tmp/checkpoints"
) -> str:
    """Download checkpoint from GCS to a local directory."""
    client = _get_gcs_client()
    bucket = client.bucket(GCS_BUCKET)
    prefix = f"{GCS_CHECKPOINT_PREFIX}{checkpoint_name}/"
    local_path = Path(local_dir) / checkpoint_name
    local_path.mkdir(parents=True, exist_ok=True)

    blobs = list(bucket.list_blobs(prefix=prefix))
    if not blobs:
        raise FileNotFoundError(f"No checkpoint found at gs://{GCS_BUCKET}/{prefix}")

    for blob in blobs:
        relative = blob.name[len(prefix) :]
        if not relative:
            continue
        dest = local_path / relative
        dest.parent.mkdir(parents=True, exist_ok=True)
        blob.download_to_filename(str(dest))

    print(
        f"Downloaded checkpoint '{checkpoint_name}' ({len(blobs)} files) to {local_path}"
    )
    return str(local_path)


def ensure_checkpoint_cached(checkpoint_name: str) -> str:
    """
    Return the checkpoint directory, using the Modal Volume as a cache.

    If the checkpoint is already on the volume, return immediately.
    Otherwise download from GCS into the volume so future containers
    skip the download.
    """
    vol_path = Path(VOLUME_CHECKPOINT_DIR) / checkpoint_name

    # Reload volume index to see writes from other containers
    checkpoint_volume.reload()

    if vol_path.exists() and any(vol_path.glob("*.pt")):
        print(f"Checkpoint '{checkpoint_name}' found in volume cache")
        return str(vol_path)

    print(f"Checkpoint '{checkpoint_name}' not cached, downloading from GCS...")
    result = download_checkpoint_from_gcs(checkpoint_name, VOLUME_CHECKPOINT_DIR)
    checkpoint_volume.commit()
    print(f"Checkpoint cached to volume for future starts")
    return result


def _upload_generated(local_path: str) -> str:
    """Upload a generated MIDI file to GCS and return its public URL."""
    filename = f"{uuid.uuid4().hex}.mid"
    blob_name = f"generated/{filename}"
    upload_to_gcs(local_path, GCS_GENERATED_BUCKET, blob_name)
    return f"https://storage.googleapis.com/{GCS_GENERATED_BUCKET}/{blob_name}"


def _find_checkpoint_file(checkpoint_dir: str) -> str:
    """Find the best checkpoint .pt file in a directory."""
    checkpoint_path = Path(checkpoint_dir)
    best = checkpoint_path / "best_model.pt"
    if best.exists():
        return str(best)
    epoch_ckpts = sorted(
        checkpoint_path.glob("checkpoint_epoch_*.pt"),
        key=lambda p: int(p.stem.split("_")[-1]),
    )
    if epoch_ckpts:
        return str(epoch_ckpts[-1])
    pt_files = list(checkpoint_path.glob("*.pt"))
    if len(pt_files) == 1:
        return str(pt_files[0])
    raise FileNotFoundError(f"No checkpoint .pt file found in {checkpoint_dir}")


# ---------------------------------------------------------------------------
# Inference
# ---------------------------------------------------------------------------


@app.cls(
    image=inference_image,
    gpu="T4",
    secrets=[GCS_SECRET],
    timeout=600,
    scaledown_window=300,
    volumes={VOLUME_CHECKPOINT_DIR: checkpoint_volume},
)
class MusicGenerator:
    checkpoint_name: str = modal.parameter(default="default")

    @modal.enter()
    def load(self):
        import torch
        from miditok import REMI

        from midi.generation.loader import load_model

        self.device = torch.device("cuda")

        # Check image-baked checkpoint first, fall back to volume/GCS
        image_path = Path(IMAGE_CHECKPOINT_DIR) / self.checkpoint_name
        if image_path.exists() and any(image_path.glob("*.pt")):
            print(f"Checkpoint '{self.checkpoint_name}' found in image")
            checkpoint_dir = str(image_path)
        else:
            checkpoint_dir = ensure_checkpoint_cached(self.checkpoint_name)

        checkpoint_file = _find_checkpoint_file(checkpoint_dir)

        tokenizer_path = Path(checkpoint_dir) / "tokenizer.json"
        if not tokenizer_path.exists():
            raise FileNotFoundError(f"No tokenizer.json found in {checkpoint_dir}")
        self.tokenizer = REMI(params=tokenizer_path)

        self.model = load_model(checkpoint_file, self.device, dtype=torch.float16)
        print(f"Model loaded from {checkpoint_file}")

    @modal.method()
    def generate_single_track(
        self,
        tags: str = None,
        num_tokens: int = 512,
        temperature: float = 1.0,
        top_k: int = 50,
        top_p: float = 0.95,
        repetition_penalty: float = 1.2,
        prompt_midi_bytes: bytes = None,
        extend_from: float = None,
        seed: int = None,
    ) -> dict:
        """Generate single-track MIDI. Returns dict with midi_bytes and gcs_url."""
        import torch

        from midi.generation.single_track import generate_music

        if seed is not None:
            torch.manual_seed(seed)

        prompt_path = None
        if prompt_midi_bytes:
            tmp = tempfile.NamedTemporaryFile(suffix=".mid", delete=False)
            tmp.write(prompt_midi_bytes)
            tmp.close()
            prompt_path = tmp.name

        output_path = tempfile.mktemp(suffix=".mid")
        try:
            generate_music(
                model=self.model,
                tokenizer=self.tokenizer,
                device=self.device,
                prompt_path=prompt_path,
                extend_from=extend_from,
                tags=tags,
                num_tokens=num_tokens,
                temperature=temperature,
                top_k=top_k,
                top_p=top_p,
                repetition_penalty=repetition_penalty,
                output_path=output_path,
            )
            gcs_url = _upload_generated(output_path)
            with open(output_path, "rb") as f:
                return {"midi_bytes": f.read(), "gcs_url": gcs_url}
        finally:
            if prompt_path:
                Path(prompt_path).unlink(missing_ok=True)
            Path(output_path).unlink(missing_ok=True)

    @modal.method()
    def generate_multitrack(
        self,
        num_tracks: int = 4,
        track_types: list[str] = None,
        instruments: list[int] = None,
        tags: str = None,
        num_tokens_per_track: int = 256,
        temperature: float = 1.0,
        top_k: int = 50,
        top_p: float = 0.95,
        repetition_penalty: float = 1.2,
        seed: int = None,
    ) -> dict:
        """Generate multitrack MIDI. Returns dict with midi_bytes and gcs_url."""
        import torch

        from midi.generation.multi_track import generate_multitrack_music

        if seed is not None:
            torch.manual_seed(seed)

        output_path = tempfile.mktemp(suffix=".mid")
        try:
            generate_multitrack_music(
                model=self.model,
                tokenizer=self.tokenizer,
                device=self.device,
                num_tracks=num_tracks,
                track_types=track_types,
                instruments=instruments,
                tags=tags,
                num_tokens_per_track=num_tokens_per_track,
                temperature=temperature,
                top_k=top_k,
                top_p=top_p,
                repetition_penalty=repetition_penalty,
                output_path=output_path,
            )
            gcs_url = _upload_generated(output_path)
            with open(output_path, "rb") as f:
                return {"midi_bytes": f.read(), "gcs_url": gcs_url}
        finally:
            Path(output_path).unlink(missing_ok=True)

    @modal.method()
    def add_track(
        self,
        midi_bytes: bytes,
        track_type: str = "melody",
        instrument: int = None,
        tags: str = None,
        num_tokens_per_track: int = 256,
        temperature: float = 1.0,
        top_k: int = 50,
        top_p: float = 0.95,
        repetition_penalty: float = 1.2,
        seed: int = None,
    ) -> dict:
        """Add a track to existing MIDI. Returns dict with midi_bytes and gcs_url."""
        import torch

        from midi.generation.multi_track import add_track_to_midi

        if seed is not None:
            torch.manual_seed(seed)

        input_tmp = tempfile.NamedTemporaryFile(suffix=".mid", delete=False)
        input_tmp.write(midi_bytes)
        input_tmp.close()

        output_path = tempfile.mktemp(suffix=".mid")
        try:
            add_track_to_midi(
                model=self.model,
                tokenizer=self.tokenizer,
                device=self.device,
                midi_path=input_tmp.name,
                track_type=track_type,
                instrument=instrument,
                tags=tags,
                num_tokens_per_track=num_tokens_per_track,
                temperature=temperature,
                top_k=top_k,
                top_p=top_p,
                repetition_penalty=repetition_penalty,
                output_path=output_path,
            )
            gcs_url = _upload_generated(output_path)
            with open(output_path, "rb") as f:
                return {"midi_bytes": f.read(), "gcs_url": gcs_url}
        finally:
            Path(input_tmp.name).unlink(missing_ok=True)
            Path(output_path).unlink(missing_ok=True)

    @modal.method()
    def replace_track(
        self,
        midi_bytes: bytes,
        track_index: int,
        track_type: str = None,
        instrument: int = None,
        replace_bars: tuple = None,
        tags: str = None,
        num_tokens_per_track: int = 256,
        temperature: float = 1.0,
        top_k: int = 50,
        top_p: float = 0.95,
        repetition_penalty: float = 1.2,
        seed: int = None,
    ) -> dict:
        """Replace a track in existing MIDI. Returns dict with midi_bytes and gcs_url."""
        import torch

        from midi.generation.multi_track import replace_track_in_midi

        if seed is not None:
            torch.manual_seed(seed)

        input_tmp = tempfile.NamedTemporaryFile(suffix=".mid", delete=False)
        input_tmp.write(midi_bytes)
        input_tmp.close()

        output_path = tempfile.mktemp(suffix=".mid")
        try:
            replace_track_in_midi(
                model=self.model,
                tokenizer=self.tokenizer,
                device=self.device,
                midi_path=input_tmp.name,
                track_index=track_index,
                track_type=track_type,
                instrument=instrument,
                replace_bars=replace_bars,
                tags=tags,
                num_tokens_per_track=num_tokens_per_track,
                temperature=temperature,
                top_k=top_k,
                top_p=top_p,
                repetition_penalty=repetition_penalty,
                output_path=output_path,
            )
            gcs_url = _upload_generated(output_path)
            with open(output_path, "rb") as f:
                return {"midi_bytes": f.read(), "gcs_url": gcs_url}
        finally:
            Path(input_tmp.name).unlink(missing_ok=True)
            Path(output_path).unlink(missing_ok=True)

    @modal.method()
    def cover(
        self,
        midi_bytes: bytes,
        num_tracks: int = None,
        track_types: list[str] = None,
        instruments: list[int] = None,
        tags: str = None,
        num_tokens_per_track: int = 256,
        temperature: float = 1.0,
        top_k: int = 50,
        top_p: float = 0.95,
        repetition_penalty: float = 1.2,
        seed: int = None,
    ) -> dict:
        """Generate a cover of existing MIDI. Returns dict with midi_bytes and gcs_url."""
        import torch

        from midi.generation.multi_track import cover_midi

        if seed is not None:
            torch.manual_seed(seed)

        input_tmp = tempfile.NamedTemporaryFile(suffix=".mid", delete=False)
        input_tmp.write(midi_bytes)
        input_tmp.close()

        output_path = tempfile.mktemp(suffix=".mid")
        try:
            cover_midi(
                model=self.model,
                tokenizer=self.tokenizer,
                device=self.device,
                midi_path=input_tmp.name,
                num_tracks=num_tracks,
                track_types=track_types,
                instruments=instruments,
                tags=tags,
                num_tokens_per_track=num_tokens_per_track,
                temperature=temperature,
                top_k=top_k,
                top_p=top_p,
                repetition_penalty=repetition_penalty,
                output_path=output_path,
            )
            gcs_url = _upload_generated(output_path)
            with open(output_path, "rb") as f:
                return {"midi_bytes": f.read(), "gcs_url": gcs_url}
        finally:
            Path(input_tmp.name).unlink(missing_ok=True)
            Path(output_path).unlink(missing_ok=True)


# ---------------------------------------------------------------------------
# Web endpoints (called by diskrot API)
# ---------------------------------------------------------------------------

web_image = inference_image.pip_install("fastapi[standard]")


@app.function(
    image=web_image,
    gpu="T4",
    secrets=[GCS_SECRET, API_KEY_SECRET],
    timeout=600,
    scaledown_window=300,
    volumes={VOLUME_CHECKPOINT_DIR: checkpoint_volume},
)
@modal.asgi_app()
def web():
    import base64

    import torch
    from fastapi import FastAPI, Request
    from fastapi.responses import JSONResponse
    from miditok import REMI
    from pydantic import BaseModel

    from midi.generation.loader import load_model
    from midi.generation.multi_track import (
        add_track_to_midi,
        cover_midi,
        generate_multitrack_music,
        replace_track_in_midi,
    )
    from midi.generation.single_track import generate_music

    web_app = FastAPI()

    @web_app.middleware("http")
    async def verify_api_key(request: Request, call_next):
        if request.url.path == "/health":
            return await call_next(request)
        api_key = os.environ.get("MODAL_API_KEY")
        if api_key and request.headers.get("X-Modal-Api-Key") != api_key:
            return JSONResponse(status_code=403, content={"detail": "Invalid API key"})
        return await call_next(request)

    # --- Model state (loaded once per container) ---
    state = {}

    def get_model(checkpoint_name: str = "default"):
        if checkpoint_name in state:
            return state[checkpoint_name]
        device = torch.device("cuda")
        checkpoint_dir = ensure_checkpoint_cached(checkpoint_name)
        checkpoint_file = _find_checkpoint_file(checkpoint_dir)
        tokenizer_path = Path(checkpoint_dir) / "tokenizer.json"
        tokenizer = REMI(params=tokenizer_path)
        model = load_model(checkpoint_file, device, dtype=torch.float16)
        state[checkpoint_name] = (model, tokenizer, device)
        return state[checkpoint_name]

    # Eagerly load default model at container startup
    get_model("default")

    # --- Request schemas ---
    class GenerateRequest(BaseModel):
        checkpoint_name: str = "default"
        tags: str | None = None
        num_tokens: int = 512
        temperature: float = 1.0
        top_k: int = 50
        top_p: float = 0.95
        repetition_penalty: float = 1.2
        seed: int | None = None
        prompt_midi_base64: str | None = None
        extend_from: float | None = None

    class MultitrackRequest(BaseModel):
        checkpoint_name: str = "default"
        num_tracks: int = 4
        track_types: list[str] | None = None
        instruments: list[int] | None = None
        tags: str | None = None
        num_tokens_per_track: int = 256
        temperature: float = 1.0
        top_k: int = 50
        top_p: float = 0.95
        repetition_penalty: float = 1.2
        seed: int | None = None

    class AddTrackRequest(BaseModel):
        checkpoint_name: str = "default"
        midi_base64: str
        track_type: str = "melody"
        instrument: int | None = None
        tags: str | None = None
        num_tokens_per_track: int = 256
        temperature: float = 1.0
        top_k: int = 50
        top_p: float = 0.95
        repetition_penalty: float = 1.2
        seed: int | None = None

    class ReplaceTrackRequest(BaseModel):
        checkpoint_name: str = "default"
        midi_base64: str
        track_index: int
        track_type: str | None = None
        instrument: int | None = None
        replace_bars: list[int] | None = None
        tags: str | None = None
        num_tokens_per_track: int = 256
        temperature: float = 1.0
        top_k: int = 50
        top_p: float = 0.95
        repetition_penalty: float = 1.2
        seed: int | None = None

    class CoverRequest(BaseModel):
        checkpoint_name: str = "default"
        midi_base64: str
        num_tracks: int | None = None
        track_types: list[str] | None = None
        instruments: list[int] | None = None
        tags: str | None = None
        num_tokens_per_track: int = 256
        temperature: float = 1.0
        top_k: int = 50
        top_p: float = 0.95
        repetition_penalty: float = 1.2
        seed: int | None = None

    # --- Helpers ---
    def _write_midi_input(midi_base64: str) -> str:
        data = base64.b64decode(midi_base64)
        tmp = tempfile.NamedTemporaryFile(suffix=".mid", delete=False)
        tmp.write(data)
        tmp.close()
        return tmp.name

    # --- Endpoints ---
    @web_app.get("/health")
    def health():
        return {"status": "ok"}

    @web_app.post("/generate")
    def generate(req: GenerateRequest):
        model, tokenizer, device = get_model(req.checkpoint_name)
        if req.seed is not None:
            torch.manual_seed(req.seed)

        prompt_path = None
        if req.prompt_midi_base64:
            prompt_path = _write_midi_input(req.prompt_midi_base64)

        output_path = tempfile.mktemp(suffix=".mid")
        try:
            generate_music(
                model=model,
                tokenizer=tokenizer,
                device=device,
                prompt_path=prompt_path,
                extend_from=req.extend_from,
                tags=req.tags,
                num_tokens=req.num_tokens,
                temperature=req.temperature,
                top_k=req.top_k,
                top_p=req.top_p,
                repetition_penalty=req.repetition_penalty,
                output_path=output_path,
            )
            gcs_url = _upload_generated(output_path)
            return {"gcs_url": gcs_url}
        finally:
            if prompt_path:
                Path(prompt_path).unlink(missing_ok=True)
            Path(output_path).unlink(missing_ok=True)

    @web_app.post("/generate/multitrack")
    def generate_multi(req: MultitrackRequest):
        model, tokenizer, device = get_model(req.checkpoint_name)
        if req.seed is not None:
            torch.manual_seed(req.seed)

        output_path = tempfile.mktemp(suffix=".mid")
        try:
            generate_multitrack_music(
                model=model,
                tokenizer=tokenizer,
                device=device,
                num_tracks=req.num_tracks,
                track_types=req.track_types,
                instruments=req.instruments,
                tags=req.tags,
                num_tokens_per_track=req.num_tokens_per_track,
                temperature=req.temperature,
                top_k=req.top_k,
                top_p=req.top_p,
                repetition_penalty=req.repetition_penalty,
                output_path=output_path,
            )
            gcs_url = _upload_generated(output_path)
            return {"gcs_url": gcs_url}
        finally:
            Path(output_path).unlink(missing_ok=True)

    @web_app.post("/generate/add-track")
    def add_track_endpoint(req: AddTrackRequest):
        model, tokenizer, device = get_model(req.checkpoint_name)
        if req.seed is not None:
            torch.manual_seed(req.seed)

        input_path = _write_midi_input(req.midi_base64)
        output_path = tempfile.mktemp(suffix=".mid")
        try:
            add_track_to_midi(
                model=model,
                tokenizer=tokenizer,
                device=device,
                midi_path=input_path,
                track_type=req.track_type,
                instrument=req.instrument,
                tags=req.tags,
                num_tokens_per_track=req.num_tokens_per_track,
                temperature=req.temperature,
                top_k=req.top_k,
                top_p=req.top_p,
                repetition_penalty=req.repetition_penalty,
                output_path=output_path,
            )
            gcs_url = _upload_generated(output_path)
            return {"gcs_url": gcs_url}
        finally:
            Path(input_path).unlink(missing_ok=True)
            Path(output_path).unlink(missing_ok=True)

    @web_app.post("/generate/replace-track")
    def replace_track_endpoint(req: ReplaceTrackRequest):
        model, tokenizer, device = get_model(req.checkpoint_name)
        if req.seed is not None:
            torch.manual_seed(req.seed)

        replace_bars_tuple = tuple(req.replace_bars) if req.replace_bars else None
        input_path = _write_midi_input(req.midi_base64)
        output_path = tempfile.mktemp(suffix=".mid")
        try:
            replace_track_in_midi(
                model=model,
                tokenizer=tokenizer,
                device=device,
                midi_path=input_path,
                track_index=req.track_index,
                track_type=req.track_type,
                instrument=req.instrument,
                replace_bars=replace_bars_tuple,
                tags=req.tags,
                num_tokens_per_track=req.num_tokens_per_track,
                temperature=req.temperature,
                top_k=req.top_k,
                top_p=req.top_p,
                repetition_penalty=req.repetition_penalty,
                output_path=output_path,
            )
            gcs_url = _upload_generated(output_path)
            return {"gcs_url": gcs_url}
        finally:
            Path(input_path).unlink(missing_ok=True)
            Path(output_path).unlink(missing_ok=True)

    @web_app.post("/generate/cover")
    def cover_endpoint(req: CoverRequest):
        model, tokenizer, device = get_model(req.checkpoint_name)
        if req.seed is not None:
            torch.manual_seed(req.seed)

        input_path = _write_midi_input(req.midi_base64)
        output_path = tempfile.mktemp(suffix=".mid")
        try:
            cover_midi(
                model=model,
                tokenizer=tokenizer,
                device=device,
                midi_path=input_path,
                num_tracks=req.num_tracks,
                track_types=req.track_types,
                instruments=req.instruments,
                tags=req.tags,
                num_tokens_per_track=req.num_tokens_per_track,
                temperature=req.temperature,
                top_k=req.top_k,
                top_p=req.top_p,
                repetition_penalty=req.repetition_penalty,
                output_path=output_path,
            )
            gcs_url = _upload_generated(output_path)
            return {"gcs_url": gcs_url}
        finally:
            Path(input_path).unlink(missing_ok=True)
            Path(output_path).unlink(missing_ok=True)

    return web_app


# ---------------------------------------------------------------------------
# Training
# ---------------------------------------------------------------------------


@app.function(
    image=image,
    gpu="A100",
    secrets=[GCS_SECRET],
    timeout=86400,
)
def train(
    checkpoint_name: str = "default",
    config: str = "configs/a100_40gb.json",
    epochs: int = None,
    batch_size: int = None,
    lr: float = None,
    grad_accum: int = None,
    load_from: str = None,
    finetune: bool = False,
    lora: bool = False,
    lora_rank: int = 8,
    lora_alpha: float = 16.0,
    freeze_layers: int = 0,
    no_warmup: bool = False,
    max_files: int = None,
):
    """
    Run training on Modal with A100 GPU.

    Downloads training data from GCS, runs training, uploads checkpoints
    back to GCS.
    """
    import subprocess
    import sys
    import zipfile

    midi_dir = "/tmp/midi_files"
    checkpoint_dir = f"/tmp/checkpoints/{checkpoint_name}"
    os.makedirs(midi_dir, exist_ok=True)
    os.makedirs(checkpoint_dir, exist_ok=True)

    # --- Step 1: Download training data ---
    print("=" * 60)
    print("STEP 1: Downloading training data from GCS")
    print("=" * 60)
    zip_path = "/tmp/midi_files.zip"
    download_from_gcs(GCS_BUCKET, GCS_TRAINING_DATA_BLOB, zip_path)

    with zipfile.ZipFile(zip_path) as zf:
        members = [
            m
            for m in zf.namelist()
            if not m.startswith("__MACOSX/") and not m.startswith("._")
        ]
        zf.extractall(midi_dir, members=members)
    os.remove(zip_path)
    print(f"Extracted training data to {midi_dir}")

    # --- Step 2: Download existing cache/tokenizer if available ---
    print("Checking for pre-tokenized cache...")
    try:
        download_from_gcs(
            GCS_BUCKET,
            f"{GCS_CHECKPOINT_PREFIX}{checkpoint_name}/token_cache.pkl",
            f"{checkpoint_dir}/token_cache.pkl",
        )
        print("Found and downloaded pre-tokenized cache")
    except Exception:
        print("No pre-tokenized cache found; will tokenize during training")

    try:
        download_from_gcs(
            GCS_BUCKET,
            f"{GCS_CHECKPOINT_PREFIX}{checkpoint_name}/tokenizer.json",
            f"{checkpoint_dir}/tokenizer.json",
        )
        print("Found and downloaded tokenizer")
    except Exception:
        print("No existing tokenizer found; will be created during training")

    # --- Step 3: Download base checkpoint for fine-tuning ---
    load_from_path = None
    if load_from:
        print(f"Downloading base checkpoint '{load_from}' for fine-tuning...")
        base_dir = download_checkpoint_from_gcs(load_from)
        load_from_path = _find_checkpoint_file(base_dir)

    # --- Step 4: Run training ---
    print("=" * 60)
    print("STEP 2: Starting training")
    print("=" * 60)

    cmd = [
        sys.executable,
        "-m",
        "midi.training.cli",
        "--midi-dir",
        midi_dir,
        "--checkpoint-dir",
        checkpoint_dir,
    ]

    if config:
        cmd.extend(["--config", f"/root/project/{config}"])
    if epochs is not None:
        cmd.extend(["--epochs", str(epochs)])
    if batch_size is not None:
        cmd.extend(["--batch-size", str(batch_size)])
    if lr is not None:
        cmd.extend(["--lr", str(lr)])
    if grad_accum is not None:
        cmd.extend(["--grad-accum", str(grad_accum)])
    if load_from_path:
        cmd.extend(["--load-from", load_from_path])
    if finetune:
        cmd.append("--finetune")
    if lora:
        cmd.append("--lora")
        cmd.extend(["--lora-rank", str(lora_rank)])
        cmd.extend(["--lora-alpha", str(lora_alpha)])
    if freeze_layers > 0:
        cmd.extend(["--freeze-layers", str(freeze_layers)])
    if no_warmup:
        cmd.append("--no-warmup")
    if max_files is not None:
        cmd.extend(["--max-files", str(max_files)])

    process = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )
    for line in process.stdout:
        print(line.rstrip())

    process.wait()
    if process.returncode != 0:
        raise RuntimeError(f"Training failed with exit code {process.returncode}")

    # --- Step 5: Upload checkpoints to GCS ---
    print("=" * 60)
    print("STEP 3: Uploading checkpoints to GCS")
    print("=" * 60)
    upload_directory_to_gcs(
        checkpoint_dir,
        GCS_BUCKET,
        f"{GCS_CHECKPOINT_PREFIX}{checkpoint_name}/",
    )
    print(
        f"Checkpoints uploaded to gs://{GCS_BUCKET}/{GCS_CHECKPOINT_PREFIX}{checkpoint_name}/"
    )

    return {"status": "complete", "checkpoint_name": checkpoint_name}


# ---------------------------------------------------------------------------
# Pretokenization (CPU)
# ---------------------------------------------------------------------------


@app.function(
    image=image,
    secrets=[GCS_SECRET],
    timeout=7200,
    cpu=8,
    memory=32768,
)
def pretokenize(
    checkpoint_name: str = "default",
    single_track: bool = False,
    use_tags: bool = True,
    max_files: int = None,
):
    """
    Pre-tokenize MIDI files on Modal (CPU).

    Downloads training data from GCS, runs pretokenization, uploads
    the token cache and tokenizer back to GCS.
    """
    import subprocess
    import sys
    import zipfile

    midi_dir = "/tmp/midi_files"
    checkpoint_dir = f"/tmp/checkpoints/{checkpoint_name}"
    os.makedirs(midi_dir, exist_ok=True)
    os.makedirs(checkpoint_dir, exist_ok=True)

    # Download training data
    zip_path = "/tmp/midi_files.zip"
    download_from_gcs(GCS_BUCKET, GCS_TRAINING_DATA_BLOB, zip_path)

    with zipfile.ZipFile(zip_path) as zf:
        members = [
            m
            for m in zf.namelist()
            if not m.startswith("__MACOSX/") and not m.startswith("._")
        ]
        zf.extractall(midi_dir, members=members)
    os.remove(zip_path)

    # Run pretokenization
    output_cache = f"{checkpoint_dir}/token_cache.pkl"
    cmd = [
        sys.executable,
        "-m",
        "midi.data.pretokenize",
        "--midi-dir",
        midi_dir,
        "--output",
        output_cache,
        "--checkpoint-interval",
        "500",
    ]
    if single_track:
        cmd.append("--single-track")
    if not use_tags:
        cmd.append("--no-tags")
    if max_files is not None:
        cmd.extend(["--max-files", str(max_files)])

    process = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )
    for line in process.stdout:
        print(line.rstrip())

    process.wait()
    if process.returncode != 0:
        raise RuntimeError(
            f"Pretokenization failed with exit code {process.returncode}"
        )

    # Upload cache and tokenizer to GCS
    upload_to_gcs(
        output_cache,
        GCS_BUCKET,
        f"{GCS_CHECKPOINT_PREFIX}{checkpoint_name}/token_cache.pkl",
    )

    tokenizer_path = f"{checkpoint_dir}/tokenizer.json"
    if Path(tokenizer_path).exists():
        upload_to_gcs(
            tokenizer_path,
            GCS_BUCKET,
            f"{GCS_CHECKPOINT_PREFIX}{checkpoint_name}/tokenizer.json",
        )

    return {"status": "complete", "checkpoint_name": checkpoint_name}


# ---------------------------------------------------------------------------
# CLI entrypoint
# ---------------------------------------------------------------------------


@app.local_entrypoint()
def main(
    action: str = "generate",
    checkpoint_name: str = "default",
    tags: str = None,
    num_tokens: int = 512,
    temperature: float = 1.0,
    output: str = "generated.mid",
    config: str = "configs/a100_40gb.json",
    epochs: int = None,
    load_from: str = None,
    finetune: bool = False,
    lora: bool = False,
    multitrack: bool = False,
    num_tracks: int = 4,
    max_files: int = None,
):
    """
    CLI entrypoint for Modal.

    Actions:
        generate      Generate MIDI (single-track or multitrack)
        pretokenize   Pre-tokenize MIDI training data
        train         Run a training job
    """
    if action == "generate":
        generator = MusicGenerator(checkpoint_name=checkpoint_name)
        if multitrack:
            result = generator.generate_multitrack.remote(
                tags=tags,
                num_tracks=num_tracks,
                num_tokens_per_track=num_tokens,
                temperature=temperature,
            )
        else:
            result = generator.generate_single_track.remote(
                tags=tags,
                num_tokens=num_tokens,
                temperature=temperature,
            )
        with open(output, "wb") as f:
            f.write(result["midi_bytes"])
        print(f"Generated MIDI saved to {output}")
        print(f"GCS: {result['gcs_url']}")

    elif action == "pretokenize":
        result = pretokenize.remote(
            checkpoint_name=checkpoint_name,
            max_files=max_files,
        )
        print(f"Pretokenization result: {result}")

    elif action == "train":
        result = train.remote(
            checkpoint_name=checkpoint_name,
            config=config,
            epochs=epochs,
            load_from=load_from,
            finetune=finetune,
            lora=lora,
            max_files=max_files,
        )
        print(f"Training result: {result}")

    else:
        print(f"Unknown action: {action}. Use 'generate', 'pretokenize', or 'train'.")
