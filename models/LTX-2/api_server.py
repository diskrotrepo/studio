"""FastAPI server for LTX-2 audio-only generation.

by diskrot

Endpoints:
- POST /release_task          Create audio generation task
- POST /query_result          Batch query task results
- GET  /v1/lora/list          List available LoRAs
- GET  /v1/lora/status        Get current LoRA status
- POST /v1/lora/load          Load a LoRA adapter
- POST /v1/lora/unload        Unload current LoRA
- POST /v1/lora/toggle        Toggle LoRA on/off
- POST /v1/lora/scale         Set LoRA scale
- GET  /output/{filename}     Download generated audio
- GET  /health                Health check

NOTE:
- In-memory queue and job store -> run uvicorn with workers=1.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import logging
import os
import time
import traceback
from collections import deque
from concurrent.futures import ThreadPoolExecutor
from contextlib import asynccontextmanager
from dataclasses import dataclass, field
from enum import IntEnum
from pathlib import Path
from threading import Lock
from typing import Any, Optional
from uuid import uuid4

import shutil

import torch
from fastapi import FastAPI, HTTPException, Header, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from pydantic import BaseModel
from tqdm import tqdm

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Download progress helpers
# ---------------------------------------------------------------------------
def _fmt_size(num_bytes: float) -> str:
    """Human-readable file size."""
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if abs(num_bytes) < 1024:
            return f"{num_bytes:.1f} {unit}"
        num_bytes /= 1024
    return f"{num_bytes:.1f} PB"


class LoggingTqdm(tqdm):
    """A tqdm subclass that periodically logs progress instead of drawing a bar.

    Logs at ~10 % intervals so server logs stay readable while still showing
    download progress for large files.
    """

    def __init__(self, *args, **kwargs):
        self._last_logged_pct = -10  # must be set before super().__init__ which calls display()
        kwargs.setdefault("mininterval", 5)  # seconds between updates
        super().__init__(*args, **kwargs)

    def display(self, msg=None, pos=None):
        if self.total and self.total > 0:
            pct = self.n / self.total * 100
            if pct - self._last_logged_pct >= 10 or pct >= 100:
                self._last_logged_pct = pct
                desc = self.desc or "Downloading"
                elapsed = self.format_interval(self.elapsed) if self.elapsed else "?"
                speed = _fmt_size(self.n / self.elapsed) + "/s" if self.elapsed and self.elapsed > 0 else "?"
                logger.info(
                    "%s: %s / %s (%.0f%%) — elapsed %s, speed %s",
                    desc, _fmt_size(self.n), _fmt_size(self.total), pct, elapsed, speed,
                )
        elif self.n > 0:
            desc = self.desc or "Downloading"
            logger.info("%s: %s downloaded", desc, _fmt_size(self.n))

    def close(self):
        if self.total and self.n >= self.total:
            desc = self.desc or "Download"
            elapsed = self.format_interval(self.elapsed) if self.elapsed else "?"
            logger.info("%s: complete — %s in %s", desc, _fmt_size(self.total), elapsed)
        super().close()

# ---------------------------------------------------------------------------
# Configuration from environment
# ---------------------------------------------------------------------------
CHECKPOINT_PATH = os.environ.get("LTX_CHECKPOINT_PATH", "/app/checkpoints")
GEMMA_ROOT = os.environ.get("LTX_GEMMA_ROOT", "/app/checkpoints/gemma")
OUTPUT_DIR = os.environ.get("LTX_OUTPUT_DIR", "/data/output")
LORA_DIR = os.environ.get("LTX_LORA_DIR", "/app/loras")
DEVICE = os.environ.get("LTX_DEVICE", "cuda")
API_HOST = os.environ.get("LTX_API_HOST", "0.0.0.0")
API_PORT = int(os.environ.get("LTX_API_PORT", "8005"))
API_KEY = os.environ.get("LTX_API_KEY", "")
MAX_QUEUE_SIZE = int(os.environ.get("LTX_MAX_QUEUE_SIZE", "32"))

# HuggingFace model repos for auto-download
LTX_HF_REPO = os.environ.get("LTX_HF_REPO", "Lightricks/LTX-2.3-fp8")
LTX_HF_CHECKPOINT = os.environ.get("LTX_HF_CHECKPOINT", "ltx-2.3-22b-dev-fp8.safetensors")
GEMMA_HF_REPO = os.environ.get("LTX_GEMMA_HF_REPO", "google/gemma-3-12b-it-qat-q4_0-unquantized")
AUDIO_CHECKPOINT_NAME = "ltx-audio-only.safetensors"


# ---------------------------------------------------------------------------
# Job store
# ---------------------------------------------------------------------------
class JobStatus(IntEnum):
    PROCESSING = 0
    SUCCEEDED = 1
    FAILED = 2


@dataclass
class JobRecord:
    job_id: str
    status: JobStatus = JobStatus.PROCESSING
    result: str = ""  # JSON-encoded list
    progress_text: str = "queued"
    created_at: float = field(default_factory=time.time)


class JobStore:
    def __init__(self) -> None:
        self._lock = Lock()
        self._jobs: dict[str, JobRecord] = {}

    def create(self) -> JobRecord:
        rec = JobRecord(job_id=uuid4().hex)
        with self._lock:
            self._jobs[rec.job_id] = rec
        return rec

    def get(self, job_id: str) -> JobRecord | None:
        with self._lock:
            return self._jobs.get(job_id)

    def update(self, job_id: str, **kwargs: Any) -> None:
        with self._lock:
            rec = self._jobs.get(job_id)
            if rec:
                for k, v in kwargs.items():
                    setattr(rec, k, v)


store = JobStore()


# ---------------------------------------------------------------------------
# LoRA state
# ---------------------------------------------------------------------------
@dataclass
class LoRAState:
    loaded_path: str | None = None
    adapter_name: str | None = None
    active: bool = False
    scale: float = 1.0


lora_state = LoRAState()


# ---------------------------------------------------------------------------
# Pipeline holder (lazy-loaded at startup)
# ---------------------------------------------------------------------------
_pipeline = None
_pipeline_lock = Lock()


def _ensure_gemma_downloaded() -> str:
    """Download Gemma text encoder if not present. Returns path to gemma root."""
    gemma_path = Path(GEMMA_ROOT)
    # Check if it already has model files
    if gemma_path.is_dir() and any(gemma_path.rglob("*.safetensors")):
        total_size = sum(f.stat().st_size for f in gemma_path.rglob("*") if f.is_file())
        logger.info("Gemma text encoder found at %s (%s on disk)", gemma_path, _fmt_size(total_size))
        return str(gemma_path)

    logger.info("=" * 60)
    logger.info("DOWNLOADING Gemma text encoder")
    logger.info("  Repo : %s", GEMMA_HF_REPO)
    logger.info("  Dest : %s", gemma_path)
    logger.info("  This is a large download and may take a while ...")
    logger.info("=" * 60)
    from huggingface_hub import snapshot_download

    gemma_path.mkdir(parents=True, exist_ok=True)
    t0 = time.time()
    snapshot_download(
        repo_id=GEMMA_HF_REPO,
        local_dir=str(gemma_path),
        local_dir_use_symlinks=False,
        tqdm_class=LoggingTqdm,
    )
    elapsed = time.time() - t0
    total_size = sum(f.stat().st_size for f in gemma_path.rglob("*") if f.is_file())
    logger.info("Gemma text encoder downloaded to %s (%s in %.1fs)", gemma_path, _fmt_size(total_size), elapsed)
    return str(gemma_path)


def _ensure_checkpoint_ready() -> str:
    """Ensure an audio-only checkpoint is available. Downloads and extracts if needed.

    Priority:
    1. Existing audio-only checkpoint (contains 'audio' in name)
    2. Any existing .safetensors (used as-is — may be full AV or audio-only)
    3. Download full checkpoint from HuggingFace, extract audio-only weights
    """
    ckpt_dir = Path(CHECKPOINT_PATH)
    ckpt_dir.mkdir(parents=True, exist_ok=True)
    logger.info("Checking for checkpoints in %s ...", ckpt_dir)

    # 1. Look for existing audio-only checkpoint
    audio_ckpt = ckpt_dir / AUDIO_CHECKPOINT_NAME
    if audio_ckpt.is_file():
        size = audio_ckpt.stat().st_size
        logger.info("Audio-only checkpoint found: %s (%s)", audio_ckpt, _fmt_size(size))
        return str(audio_ckpt)

    # 2. Look for any existing .safetensors file
    all_safetensors = sorted(ckpt_dir.rglob("*.safetensors"))
    # Filter out files inside the gemma subdirectory
    non_gemma = [f for f in all_safetensors if "gemma" not in str(f).lower()]

    if non_gemma:
        full_ckpt = non_gemma[0]
        size = full_ckpt.stat().st_size
        logger.info("Found checkpoint: %s (%s) — will extract audio-only weights ...", full_ckpt, _fmt_size(size))
        _extract_audio(str(full_ckpt), str(audio_ckpt))
        return str(audio_ckpt)

    # 3. No checkpoint at all — download from HuggingFace
    disk = shutil.disk_usage(str(ckpt_dir))
    logger.info("=" * 60)
    logger.info("DOWNLOADING LTX checkpoint")
    logger.info("  Repo : %s", LTX_HF_REPO)
    logger.info("  File : %s", LTX_HF_CHECKPOINT)
    logger.info("  Dest : %s", ckpt_dir)
    logger.info("  Free disk space: %s", _fmt_size(disk.free))
    logger.info("  This is a large download and may take a while ...")
    logger.info("=" * 60)
    from huggingface_hub import hf_hub_download

    t0 = time.time()
    downloaded = hf_hub_download(
        repo_id=LTX_HF_REPO,
        filename=LTX_HF_CHECKPOINT,
        local_dir=str(ckpt_dir),
        local_dir_use_symlinks=False,
        tqdm_class=LoggingTqdm,
    )
    elapsed = time.time() - t0
    dl_size = Path(downloaded).stat().st_size
    logger.info("Downloaded checkpoint to %s (%s in %.1fs)", downloaded, _fmt_size(dl_size), elapsed)

    # Extract audio-only weights
    logger.info("Extracting audio-only weights from %s ...", Path(downloaded).name)
    _extract_audio(downloaded, str(audio_ckpt))
    return str(audio_ckpt)


def _extract_audio(input_path: str, output_path: str) -> None:
    """Extract audio-only weights from a full AV checkpoint."""
    from ltx_pipelines.extract_audio_checkpoint import extract_audio_checkpoint

    in_size = Path(input_path).stat().st_size
    logger.info("Extracting audio-only weights: %s (%s) -> %s", Path(input_path).name, _fmt_size(in_size), output_path)
    t0 = time.time()
    extract_audio_checkpoint(input_path, output_path)
    elapsed = time.time() - t0
    out_size = Path(output_path).stat().st_size
    logger.info("Audio-only checkpoint saved to %s (%s, took %.1fs)", output_path, _fmt_size(out_size), elapsed)


def _load_pipeline() -> Any:
    global _pipeline
    with _pipeline_lock:
        if _pipeline is not None:
            return _pipeline

        from ltx_core.loader import LoraPathStrengthAndSDOps
        from ltx_pipelines.audio_only import AudioOnlyPipeline

        pipeline_t0 = time.time()
        logger.info("=" * 60)
        logger.info("INITIALIZING LTX-2 PIPELINE")
        logger.info("=" * 60)

        # Auto-download and prepare checkpoint + gemma
        logger.info("[1/3] Preparing LTX checkpoint ...")
        ckpt = _ensure_checkpoint_ready()

        logger.info("[2/3] Preparing Gemma text encoder ...")
        gemma_root = _ensure_gemma_downloaded()

        dev = torch.device(DEVICE if DEVICE != "cpu" and torch.cuda.is_available() else "cpu")
        if dev.type == "cuda" and torch.cuda.is_available():
            gpu_name = torch.cuda.get_device_name(0)
            free_mem, total_mem = torch.cuda.mem_get_info(0)
            logger.info("GPU: %s (%s VRAM, %s free)", gpu_name, _fmt_size(total_mem), _fmt_size(free_mem))
        else:
            logger.info("Device: CPU (no CUDA GPU detected)")

        loras: list[LoraPathStrengthAndSDOps] = []
        if lora_state.loaded_path and lora_state.active:
            loras = [LoraPathStrengthAndSDOps(path=lora_state.loaded_path, strength=lora_state.scale)]
            logger.info("LoRA: %s (scale=%.2f)", lora_state.loaded_path, lora_state.scale)

        logger.info("[3/3] Building pipeline: checkpoint=%s, gemma=%s, device=%s", ckpt, gemma_root, dev)
        model_t0 = time.time()
        _pipeline = AudioOnlyPipeline(
            checkpoint_path=ckpt,
            gemma_root=gemma_root,
            loras=tuple(loras),
            device=dev,
        )
        model_elapsed = time.time() - model_t0
        total_elapsed = time.time() - pipeline_t0
        logger.info("Pipeline model loading took %.1fs", model_elapsed)
        logger.info("=" * 60)
        logger.info("LTX-2 PIPELINE READY (total init: %.1fs)", total_elapsed)
        logger.info("=" * 60)
        return _pipeline


def _reload_pipeline() -> Any:
    """Force-reload the pipeline (e.g. after LoRA changes)."""
    global _pipeline
    with _pipeline_lock:
        _pipeline = None
    return _load_pipeline()


# ---------------------------------------------------------------------------
# Generation worker
# ---------------------------------------------------------------------------
@torch.inference_mode()
def _run_generation(job_id: str, params: dict[str, Any]) -> None:
    try:
        logger.info("[%s] Starting generation ...", job_id)
        store.update(job_id, progress_text="loading model")
        t0 = time.time()
        pipeline = _load_pipeline()
        logger.info("[%s] Pipeline ready (%.1fs)", job_id, time.time() - t0)

        store.update(job_id, progress_text="generating")

        prompt = params.get("prompt", "")
        seed = int(params.get("seed", 171198))
        num_frames = int(params.get("num_frames", 121))
        frame_rate = float(params.get("frame_rate", 24.0))
        enhance_prompt = bool(params.get("enhance_prompt", False))
        batch_size = int(params.get("batch_size", 1))
        negative_prompt = params.get("negative_prompt", "")
        audio_cfg_guidance_scale = float(params.get("audio_cfg_guidance_scale", 7.0))
        audio_stg_guidance_scale = float(params.get("audio_stg_guidance_scale", 1.0))
        audio_rescale_scale = float(params.get("audio_rescale_scale", 0.7))

        logger.info(
            "[%s] Params: prompt=%r, seed=%d, frames=%d, fps=%.1f, batch=%d, "
            "cfg=%.1f, stg=%.1f, rescale=%.1f",
            job_id, prompt[:80], seed, num_frames, frame_rate, batch_size,
            audio_cfg_guidance_scale, audio_stg_guidance_scale, audio_rescale_scale,
        )

        results = []
        gen_t0 = time.time()
        for i in range(batch_size):
            current_seed = seed + i
            logger.info("[%s] Generating batch item %d/%d (seed=%d) ...", job_id, i + 1, batch_size, current_seed)
            audio = pipeline(
                prompt=prompt,
                seed=current_seed,
                num_frames=num_frames,
                frame_rate=frame_rate,
                enhance_prompt=enhance_prompt,
                negative_prompt=negative_prompt,
                audio_cfg_guidance_scale=audio_cfg_guidance_scale,
                audio_stg_guidance_scale=audio_stg_guidance_scale,
                audio_rescale_scale=audio_rescale_scale,
            )

            out_dir = Path(OUTPUT_DIR)
            out_dir.mkdir(parents=True, exist_ok=True)
            filename = f"{job_id}_{i}.wav"
            out_path = out_dir / filename

            from ltx_pipelines.utils.media_io import encode_audio_wav
            encode_audio_wav(audio, str(out_path))

            results.append({"file": f"/output/{filename}", "status": 1})
            logger.info("[%s] Saved %s", job_id, out_path)

        gen_elapsed = time.time() - gen_t0
        logger.info("[%s] Generation complete (%d items in %.1fs)", job_id, len(results), gen_elapsed)
        store.update(
            job_id,
            status=JobStatus.SUCCEEDED,
            result=json.dumps(results, ensure_ascii=False),
            progress_text="completed",
        )

    except Exception:
        tb = traceback.format_exc()
        logger.error("[%s] Generation FAILED:\n%s", job_id, tb)
        store.update(
            job_id,
            status=JobStatus.FAILED,
            result=json.dumps([], ensure_ascii=False),
            progress_text=f"failed: {tb[:500]}",
        )


# ---------------------------------------------------------------------------
# Auth helper
# ---------------------------------------------------------------------------
def _verify_api_key(body: dict | None = None, authorization: str | None = None) -> None:
    if not API_KEY:
        return
    token = None
    if authorization:
        token = authorization.removeprefix("Bearer ").strip()
    if not token and body:
        token = body.get("api_key") or body.get("token")
    if token != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API key")


# ---------------------------------------------------------------------------
# App lifecycle
# ---------------------------------------------------------------------------
@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.job_queue: asyncio.Queue = asyncio.Queue(maxsize=MAX_QUEUE_SIZE)
    app.state.executor = ThreadPoolExecutor(max_workers=1, thread_name_prefix="ltx-gen")
    app.state.pending_ids: deque[str] = deque()
    app.state.pending_lock = asyncio.Lock()

    # Start worker task
    worker_task = asyncio.create_task(_queue_worker(app))

    # Pre-load the pipeline in the background
    loop = asyncio.get_event_loop()
    loop.run_in_executor(app.state.executor, _load_pipeline)

    yield

    worker_task.cancel()
    app.state.executor.shutdown(wait=False)


async def _queue_worker(app: FastAPI) -> None:
    loop = asyncio.get_event_loop()
    while True:
        job_id, params = await app.state.job_queue.get()
        logger.info("Worker dequeued job %s (prompt=%r)", job_id, (params.get("prompt", "")[:80]))
        async with app.state.pending_lock:
            if job_id in app.state.pending_ids:
                app.state.pending_ids.remove(job_id)
        await loop.run_in_executor(app.state.executor, _run_generation, job_id, params)


def _wrap_response(data: Any) -> dict:
    return {"code": 0, "msg": "success", "data": data}


# ---------------------------------------------------------------------------
# FastAPI app
# ---------------------------------------------------------------------------
app = FastAPI(title="LTX-2 Audio Server", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/release_task")
async def release_task(request: Request, authorization: Optional[str] = Header(None)):
    body = await request.json()
    _verify_api_key(body, authorization)

    rec = store.create()
    q: asyncio.Queue = app.state.job_queue
    if q.full():
        raise HTTPException(status_code=429, detail="Server busy: queue is full")

    async with app.state.pending_lock:
        app.state.pending_ids.append(rec.job_id)
        position = len(app.state.pending_ids)

    await q.put((rec.job_id, body))
    return _wrap_response({"task_id": rec.job_id, "status": "queued", "queue_position": position})


@app.post("/query_result")
async def query_result(request: Request, authorization: Optional[str] = Header(None)):
    body = await request.json()
    _verify_api_key(body, authorization)

    task_id_list = body.get("task_id_list", [])
    if isinstance(task_id_list, str):
        task_id_list = json.loads(task_id_list)

    data_list = []
    for task_id in task_id_list:
        rec = store.get(task_id)
        if rec:
            data_list.append({
                "task_id": task_id,
                "result": rec.result,
                "status": int(rec.status),
                "progress_text": rec.progress_text,
            })
        else:
            data_list.append({
                "task_id": task_id,
                "result": "[]",
                "status": 2,
                "progress_text": "task not found",
            })

    return _wrap_response(data_list)


@app.get("/output/{filename:path}")
async def serve_output(filename: str):
    filepath = Path(OUTPUT_DIR) / filename
    if not filepath.is_file():
        raise HTTPException(status_code=404, detail="File not found")
    return FileResponse(str(filepath), media_type="audio/wav")


# ---------------------------------------------------------------------------
# LoRA endpoints
# ---------------------------------------------------------------------------
class LoadLoRARequest(BaseModel):
    lora_path: str
    adapter_name: str | None = None


class ToggleLoRARequest(BaseModel):
    use_lora: bool


class SetLoRAScaleRequest(BaseModel):
    scale: float
    adapter_name: str | None = None


@app.get("/v1/lora/list")
async def list_loras(authorization: Optional[str] = Header(None)):
    _verify_api_key(authorization=authorization)
    lora_dir = Path(LORA_DIR)
    loras = []
    if lora_dir.is_dir():
        for f in sorted(lora_dir.iterdir()):
            if f.suffix == ".safetensors" or f.is_dir():
                loras.append({"name": f.stem, "path": str(f)})
    return _wrap_response(loras)


@app.get("/v1/lora/status")
async def get_lora_status(authorization: Optional[str] = Header(None)):
    _verify_api_key(authorization=authorization)
    return _wrap_response({
        "loaded": lora_state.loaded_path is not None,
        "active": lora_state.active,
        "path": lora_state.loaded_path,
        "adapter_name": lora_state.adapter_name,
        "scale": lora_state.scale,
    })


@app.post("/v1/lora/load")
async def load_lora(req: LoadLoRARequest, authorization: Optional[str] = Header(None)):
    _verify_api_key(authorization=authorization)
    path = Path(req.lora_path)
    if not path.exists():
        # Try relative to LORA_DIR
        path = Path(LORA_DIR) / req.lora_path
    if not path.exists():
        raise HTTPException(status_code=404, detail=f"LoRA not found: {req.lora_path}")

    lora_state.loaded_path = str(path)
    lora_state.adapter_name = req.adapter_name or path.stem
    lora_state.active = True

    _reload_pipeline()
    return _wrap_response({"loaded": str(path), "adapter_name": lora_state.adapter_name})


@app.post("/v1/lora/unload")
async def unload_lora(authorization: Optional[str] = Header(None)):
    _verify_api_key(authorization=authorization)
    lora_state.loaded_path = None
    lora_state.adapter_name = None
    lora_state.active = False
    lora_state.scale = 1.0

    _reload_pipeline()
    return _wrap_response({"unloaded": True})


@app.post("/v1/lora/toggle")
async def toggle_lora(req: ToggleLoRARequest, authorization: Optional[str] = Header(None)):
    _verify_api_key(authorization=authorization)
    if req.use_lora and not lora_state.loaded_path:
        raise HTTPException(status_code=400, detail="No LoRA loaded")
    lora_state.active = req.use_lora

    _reload_pipeline()
    return _wrap_response({"active": lora_state.active})


@app.post("/v1/lora/scale")
async def set_lora_scale(req: SetLoRAScaleRequest, authorization: Optional[str] = Header(None)):
    _verify_api_key(authorization=authorization)
    lora_state.scale = req.scale

    if lora_state.active:
        _reload_pipeline()
    return _wrap_response({"scale": lora_state.scale})


# ---------------------------------------------------------------------------
# CLI entry
# ---------------------------------------------------------------------------
def main() -> None:
    import uvicorn

    parser = argparse.ArgumentParser(description="LTX-2 Audio API Server")
    parser.add_argument("--host", default=API_HOST)
    parser.add_argument("--port", type=int, default=API_PORT)
    args = parser.parse_args()

    uvicorn.run(app, host=args.host, port=args.port, workers=1)


if __name__ == "__main__":
    main()
