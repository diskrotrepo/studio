"""Bark TTS — FastAPI server.

Exposes a simple REST API for text-to-speech generation using Suno Bark.
"""

import io
import logging
import os
import uuid
from contextlib import asynccontextmanager

logging.basicConfig(
    format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
    level=logging.INFO,
)
logger = logging.getLogger("bark")

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse, JSONResponse
import numpy as np
from pydantic import BaseModel, Field
from scipy.io.wavfile import write as write_wav
import uvicorn

from bark.api import generate_audio, text_to_semantic, semantic_to_waveform
from bark.generation import SAMPLE_RATE, preload_models


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Preload models on startup so first request isn't slow."""
    logger.info("Loading Bark models (this may take a while)...")
    preload_models()
    logger.info("Bark models loaded.")
    yield


app = FastAPI(title="Bark TTS", version="0.1.0", lifespan=lifespan)

OUTPUT_DIR = os.environ.get("BARK_OUTPUT_DIR", "/data/output")
os.makedirs(OUTPUT_DIR, exist_ok=True)


class GenerateRequest(BaseModel):
    text: str
    history_prompt: str | None = None
    text_temp: float = Field(default=0.7, ge=0.0, le=1.5)
    waveform_temp: float = Field(default=0.7, ge=0.0, le=1.5)


class GenerateLongRequest(BaseModel):
    """Long-form generation via history-prompt chaining.

    Splits text into segments, generates each one while feeding the previous
    generation as the history prompt for the next, then concatenates into a
    single WAV file.
    """

    segments: list[str] = Field(
        ..., min_length=1, description="Ordered text segments to generate."
    )
    history_prompt: str | None = Field(
        default=None,
        description="Initial voice preset (e.g. 'v2/en_speaker_6').",
    )
    text_temp: float = Field(default=0.7, ge=0.0, le=1.5)
    waveform_temp: float = Field(default=0.7, ge=0.0, le=1.5)
    min_eos_p: float = Field(
        default=0.05,
        ge=0.01,
        le=1.0,
        description="Early-stopping threshold. Lower = longer per-segment audio.",
    )
    silence_duration_s: float = Field(
        default=0.25,
        ge=0.0,
        le=2.0,
        description="Seconds of silence between segments.",
    )


class GenerateResponse(BaseModel):
    file: str
    sample_rate: int


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/generate", response_model=GenerateResponse)
async def generate(req: GenerateRequest):
    try:
        audio_arr = generate_audio(
            req.text,
            history_prompt=req.history_prompt,
            text_temp=req.text_temp,
            waveform_temp=req.waveform_temp,
            silent=True,
        )
        filename = f"{uuid.uuid4().hex}.wav"
        filepath = os.path.join(OUTPUT_DIR, filename)
        write_wav(filepath, SAMPLE_RATE, audio_arr)
        return GenerateResponse(file=filename, sample_rate=SAMPLE_RATE)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/generate_long", response_model=GenerateResponse)
async def generate_long(req: GenerateLongRequest):
    """Generate long-form audio via history-prompt chaining.

    Each segment is generated using the *previous* segment's full output as
    the history prompt, which keeps the voice consistent across the entire
    piece.  The advanced two-step pipeline (text→semantic with min_eos_p,
    then semantic→waveform) is used instead of the simple generate_audio()
    call to give control over early-stopping behavior.
    """
    try:
        from bark.generation import generate_text_semantic

        silence = np.zeros(int(req.silence_duration_s * SAMPLE_RATE))
        pieces: list[np.ndarray] = []
        history = req.history_prompt  # str | dict | None

        for segment in req.segments:
            semantic_tokens = generate_text_semantic(
                segment,
                history_prompt=history,
                temp=req.text_temp,
                min_eos_p=req.min_eos_p,
                silent=True,
                use_kv_caching=True,
            )
            full_generation, audio_arr = semantic_to_waveform(
                semantic_tokens,
                history_prompt=history,
                temp=req.waveform_temp,
                silent=True,
                output_full=True,
            )
            pieces.append(audio_arr)
            pieces.append(silence.copy())
            # Chain: use this segment's full output as the next prompt
            history = full_generation

        combined = np.concatenate(pieces)
        filename = f"{uuid.uuid4().hex}.wav"
        filepath = os.path.join(OUTPUT_DIR, filename)
        write_wav(filepath, SAMPLE_RATE, combined)
        return GenerateResponse(file=filename, sample_rate=SAMPLE_RATE)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/output/{filename}")
async def get_output(filename: str):
    filepath = os.path.join(OUTPUT_DIR, filename)
    if not os.path.isfile(filepath):
        raise HTTPException(status_code=404, detail="File not found")
    return FileResponse(filepath, media_type="audio/wav")


if __name__ == "__main__":
    port = int(os.environ.get("BARK_PORT", "8002"))
    uvicorn.run("api_server:app", host="0.0.0.0", port=port)
