"""
Service layer for MIDI generation.

Wraps the generate.py functions for use by the API.
"""

import os
import uuid
import shutil
import tempfile
from datetime import datetime, timedelta
from pathlib import Path

import logging

from django.conf import settings

logger = logging.getLogger(__name__)

HUMANIZE_PRESETS = {
    "light": dict(
        timing_jitter_ms=10, velocity_jitter=5,
        duration_variance=0.03, beat_accent=5,
        legato_overlap=1.02, phrase_dynamics=0.06, swing_amount=0.0,
    ),
    "medium": dict(
        timing_jitter_ms=18, velocity_jitter=10,
        duration_variance=0.05, beat_accent=10,
        legato_overlap=1.05, phrase_dynamics=0.12, swing_amount=0.05,
    ),
    "heavy": dict(
        timing_jitter_ms=25, velocity_jitter=15,
        duration_variance=0.08, beat_accent=14,
        legato_overlap=1.08, phrase_dynamics=0.18, swing_amount=0.12,
    ),
}


class GenerationService:
    """Service for handling MIDI generation operations."""

    @staticmethod
    def calculate_num_tokens(duration: int, bpm: int) -> int:
        """Calculate number of tokens based on duration and BPM.

        REMI tokenization uses ~4 tokens per note (Position + Pitch +
        Velocity + Duration) plus Bar markers, so actual token density
        is roughly 30 tokens/second at 120 BPM.
        """
        tokens_per_second = 30 * (bpm / 120.0)
        return int(duration * tokens_per_second)

    @staticmethod
    def generate_file_id() -> str:
        """Generate a unique file ID."""
        return uuid.uuid4().hex

    @staticmethod
    def get_file_path(file_id: str, extension: str = 'mid') -> Path:
        """Get the path for a generated file."""
        return settings.GENERATED_FILES_DIR / f"{file_id}.{extension}"

    @staticmethod
    def get_expiry_time() -> datetime:
        """Get the expiry time for a generated file."""
        return datetime.utcnow() + timedelta(hours=settings.FILE_EXPIRY_HOURS)

    @classmethod
    def _apply_humanize(cls, midi_path: str, preset_name: str):
        """Apply humanization post-processing to a MIDI file."""
        from midi.tokenization.midi_io import humanize_midi
        from symusic import Score

        preset = HUMANIZE_PRESETS[preset_name]
        score = Score(midi_path)
        score = humanize_midi(score, **preset)
        score.dump_midi(midi_path)
        logger.info(f"Applied '{preset_name}' humanization to {midi_path}")

    @classmethod
    def generate_single_track(
        cls,
        tags: str | None = None,
        duration: int = 60,
        bpm: int = 120,
        temperature: float = 1.0,
        top_k: int = 50,
        top_p: float = 0.95,
        repetition_penalty: float = 1.2,
        humanize: str | None = None,
        output_format: str = 'midi',
        seed: int | None = None,
        prompt_path: str | None = None,
        extend_from: float | None = None,
        progress_callback=None,
        model_name: str = "default",
    ) -> dict:
        """
        Generate single-track MIDI music.

        Returns:
            dict with file_id, midi_path, and optionally mp3_path
        """
        import torch
        from api.apps import ApiConfig
        from midi.generation import generate_music, midi_to_mp3

        # Set seed if provided
        if seed is not None:
            torch.manual_seed(seed)

        # Get loaded model, tokenizer, device
        model = ApiConfig.get_model(model_name)
        tokenizer = ApiConfig.get_tokenizer(model_name)
        device = ApiConfig.get_device()

        # Calculate tokens
        num_tokens = cls.calculate_num_tokens(duration, bpm)

        # Generate file ID and paths
        file_id = cls.generate_file_id()
        midi_path = str(cls.get_file_path(file_id, 'mid'))

        logger.info(f"Generating single-track: file_id={file_id}, tokens={num_tokens}")

        # Generate music
        generate_music(
            model=model,
            tokenizer=tokenizer,
            device=device,
            prompt_path=prompt_path,
            extend_from=extend_from,
            tags=tags,
            num_tokens=num_tokens,
            temperature=temperature,
            top_k=top_k,
            top_p=top_p,
            repetition_penalty=repetition_penalty,
            output_path=midi_path,
            progress_callback=progress_callback,
        )

        # Apply humanization if requested
        if humanize:
            if progress_callback:
                progress_callback(0.92, 'Applying humanization...')
            cls._apply_humanize(midi_path, humanize)

        result = {
            'file_id': file_id,
            'midi_path': midi_path,
            'expires_at': cls.get_expiry_time().isoformat(),
        }

        # Convert to MP3 if requested
        if output_format in ('mp3', 'both'):
            if progress_callback:
                progress_callback(0.95, 'Converting to MP3...')
            mp3_path = str(cls.get_file_path(file_id, 'mp3'))
            soundfont = getattr(settings, 'MIDI_SOUNDFONT', None)
            success = midi_to_mp3(midi_path, mp3_path, soundfont)
            if success:
                result['mp3_path'] = mp3_path
                logger.info(f"MP3 conversion successful: {mp3_path}")
            else:
                logger.warning("MP3 conversion failed")

        # Remove MIDI if only MP3 was requested
        if output_format == 'mp3' and 'mp3_path' in result:
            os.remove(midi_path)
            del result['midi_path']

        logger.info(f"Generation complete: {result}")
        return result

    @classmethod
    def generate_multitrack(
        cls,
        num_tracks: int = 4,
        track_types: list | None = None,
        instruments: list | None = None,
        tags: str | None = None,
        duration: int = 60,
        bpm: int = 120,
        temperature: float = 1.0,
        top_k: int = 50,
        top_p: float = 0.95,
        repetition_penalty: float = 1.2,
        humanize: str | None = None,
        output_format: str = 'midi',
        seed: int | None = None,
        progress_callback=None,
        model_name: str = "default",
    ) -> dict:
        """
        Generate multi-track MIDI music.

        Returns:
            dict with file_id, midi_path, and optionally mp3_path
        """
        import torch
        from api.apps import ApiConfig
        from midi.generation import generate_multitrack_music, midi_to_mp3

        # Set seed if provided
        if seed is not None:
            torch.manual_seed(seed)

        # Get loaded model, tokenizer, device
        model = ApiConfig.get_multitrack_model(model_name)
        tokenizer = ApiConfig.get_tokenizer(model_name)
        device = ApiConfig.get_device()

        # Each track independently covers the full duration
        tokens_per_track = cls.calculate_num_tokens(duration, bpm)

        # Generate file ID and paths
        file_id = cls.generate_file_id()
        midi_path = str(cls.get_file_path(file_id, 'mid'))

        logger.info(f"Generating multitrack: file_id={file_id}, tracks={num_tracks}")

        # Generate music
        generate_multitrack_music(
            model=model,
            tokenizer=tokenizer,
            device=device,
            num_tracks=num_tracks,
            track_types=track_types,
            instruments=instruments,
            tags=tags,
            num_tokens_per_track=tokens_per_track,
            temperature=temperature,
            top_k=top_k,
            top_p=top_p,
            repetition_penalty=repetition_penalty,
            output_path=midi_path,
            progress_callback=progress_callback,
        )

        # Apply humanization if requested
        if humanize:
            if progress_callback:
                progress_callback(0.92, 'Applying humanization...')
            cls._apply_humanize(midi_path, humanize)

        result = {
            'file_id': file_id,
            'midi_path': midi_path,
            'expires_at': cls.get_expiry_time().isoformat(),
        }

        # Convert to MP3 if requested
        if output_format in ('mp3', 'both'):
            if progress_callback:
                progress_callback(0.95, 'Converting to MP3...')
            mp3_path = str(cls.get_file_path(file_id, 'mp3'))
            soundfont = getattr(settings, 'MIDI_SOUNDFONT', None)
            success = midi_to_mp3(midi_path, mp3_path, soundfont)
            if success:
                result['mp3_path'] = mp3_path

        # Remove MIDI if only MP3 was requested
        if output_format == 'mp3' and 'mp3_path' in result:
            os.remove(midi_path)
            del result['midi_path']

        logger.info(f"Multitrack generation complete: {result}")
        return result

    @classmethod
    def add_track(
        cls,
        prompt_path: str,
        track_type: str = 'melody',
        instrument: int | None = None,
        tags: str | None = None,
        duration: int = 60,
        bpm: int = 120,
        temperature: float = 1.0,
        top_k: int = 50,
        top_p: float = 0.95,
        repetition_penalty: float = 1.2,
        humanize: str | None = None,
        output_format: str = 'midi',
        seed: int | None = None,
        progress_callback=None,
        model_name: str = "default",
    ) -> dict:
        """
        Add a new track to an existing MIDI file.

        Returns:
            dict with file_id, midi_path, and optionally mp3_path
        """
        import torch
        from api.apps import ApiConfig
        from midi.generation import add_track_to_midi, midi_to_mp3

        if seed is not None:
            torch.manual_seed(seed)

        model = ApiConfig.get_multitrack_model(model_name)
        tokenizer = ApiConfig.get_tokenizer(model_name)
        device = ApiConfig.get_device()

        total_tokens = cls.calculate_num_tokens(duration, bpm)

        file_id = cls.generate_file_id()
        midi_path = str(cls.get_file_path(file_id, 'mid'))

        logger.info(f"Adding track: file_id={file_id}, type={track_type}")

        add_track_to_midi(
            model=model,
            tokenizer=tokenizer,
            device=device,
            midi_path=prompt_path,
            track_type=track_type,
            instrument=instrument,
            tags=tags,
            num_tokens_per_track=total_tokens,
            temperature=temperature,
            top_k=top_k,
            top_p=top_p,
            repetition_penalty=repetition_penalty,
            output_path=midi_path,
            progress_callback=progress_callback,
        )

        if humanize:
            if progress_callback:
                progress_callback(0.92, 'Applying humanization...')
            cls._apply_humanize(midi_path, humanize)

        result = {
            'file_id': file_id,
            'midi_path': midi_path,
            'expires_at': cls.get_expiry_time().isoformat(),
        }

        if output_format in ('mp3', 'both'):
            if progress_callback:
                progress_callback(0.95, 'Converting to MP3...')
            mp3_path = str(cls.get_file_path(file_id, 'mp3'))
            soundfont = getattr(settings, 'MIDI_SOUNDFONT', None)
            success = midi_to_mp3(midi_path, mp3_path, soundfont)
            if success:
                result['mp3_path'] = mp3_path

        if output_format == 'mp3' and 'mp3_path' in result:
            os.remove(midi_path)
            del result['midi_path']

        logger.info(f"Add track complete: {result}")
        return result

    @classmethod
    def replace_track(
        cls,
        prompt_path: str,
        track_index: int,
        track_type: str | None = None,
        instrument: int | None = None,
        replace_bars: tuple | None = None,
        tags: str | None = None,
        duration: int = 60,
        bpm: int = 120,
        temperature: float = 1.0,
        top_k: int = 50,
        top_p: float = 0.95,
        repetition_penalty: float = 1.2,
        humanize: str | None = None,
        output_format: str = 'midi',
        seed: int | None = None,
        progress_callback=None,
        model_name: str = "default",
    ) -> dict:
        """
        Replace a track (or bars within a track) in an existing MIDI file.

        Args:
            track_index: 0-based track index
            replace_bars: None for full track, (start,) for start-to-end,
                         (start, end) for specific range (0-based)

        Returns:
            dict with file_id, midi_path, and optionally mp3_path
        """
        import torch
        from api.apps import ApiConfig
        from midi.generation import replace_track_in_midi, midi_to_mp3

        if seed is not None:
            torch.manual_seed(seed)

        model = ApiConfig.get_multitrack_model(model_name)
        tokenizer = ApiConfig.get_tokenizer(model_name)
        device = ApiConfig.get_device()

        total_tokens = cls.calculate_num_tokens(duration, bpm)

        file_id = cls.generate_file_id()
        midi_path = str(cls.get_file_path(file_id, 'mid'))

        logger.info(f"Replacing track: file_id={file_id}, track_index={track_index}, bars={replace_bars}")

        replace_track_in_midi(
            model=model,
            tokenizer=tokenizer,
            device=device,
            midi_path=prompt_path,
            track_index=track_index,
            track_type=track_type,
            instrument=instrument,
            replace_bars=replace_bars,
            tags=tags,
            num_tokens_per_track=total_tokens,
            temperature=temperature,
            top_k=top_k,
            top_p=top_p,
            repetition_penalty=repetition_penalty,
            output_path=midi_path,
            progress_callback=progress_callback,
        )

        if humanize:
            if progress_callback:
                progress_callback(0.92, 'Applying humanization...')
            cls._apply_humanize(midi_path, humanize)

        result = {
            'file_id': file_id,
            'midi_path': midi_path,
            'expires_at': cls.get_expiry_time().isoformat(),
        }

        if output_format in ('mp3', 'both'):
            if progress_callback:
                progress_callback(0.95, 'Converting to MP3...')
            mp3_path = str(cls.get_file_path(file_id, 'mp3'))
            soundfont = getattr(settings, 'MIDI_SOUNDFONT', None)
            success = midi_to_mp3(midi_path, mp3_path, soundfont)
            if success:
                result['mp3_path'] = mp3_path

        if output_format == 'mp3' and 'mp3_path' in result:
            os.remove(midi_path)
            del result['midi_path']

        logger.info(f"Replace track complete: {result}")
        return result

    @classmethod
    def cover(
        cls,
        prompt_path: str,
        num_tracks: int | None = None,
        track_types: list | None = None,
        instruments: list | None = None,
        tags: str | None = None,
        duration: int = 60,
        bpm: int = 120,
        temperature: float = 1.0,
        top_k: int = 50,
        top_p: float = 0.95,
        repetition_penalty: float = 1.2,
        humanize: str | None = None,
        output_format: str = 'midi',
        seed: int | None = None,
        progress_callback=None,
        model_name: str = "default",
    ) -> dict:
        """
        Generate a cover of an existing MIDI file.

        Returns:
            dict with file_id, midi_path, and optionally mp3_path
        """
        import torch
        from api.apps import ApiConfig
        from midi.generation import cover_midi, midi_to_mp3

        if seed is not None:
            torch.manual_seed(seed)

        model = ApiConfig.get_multitrack_model(model_name)
        tokenizer = ApiConfig.get_tokenizer(model_name)
        device = ApiConfig.get_device()

        tokens_per_track = cls.calculate_num_tokens(duration, bpm)

        file_id = cls.generate_file_id()
        midi_path = str(cls.get_file_path(file_id, 'mid'))

        logger.info(f"Covering MIDI: file_id={file_id}, reference={prompt_path}")

        cover_midi(
            model=model,
            tokenizer=tokenizer,
            device=device,
            midi_path=prompt_path,
            num_tracks=num_tracks,
            track_types=track_types,
            instruments=instruments,
            tags=tags,
            num_tokens_per_track=tokens_per_track,
            temperature=temperature,
            top_k=top_k,
            top_p=top_p,
            repetition_penalty=repetition_penalty,
            output_path=midi_path,
            progress_callback=progress_callback,
        )

        if humanize:
            if progress_callback:
                progress_callback(0.92, 'Applying humanization...')
            cls._apply_humanize(midi_path, humanize)

        result = {
            'file_id': file_id,
            'midi_path': midi_path,
            'expires_at': cls.get_expiry_time().isoformat(),
        }

        if output_format in ('mp3', 'both'):
            if progress_callback:
                progress_callback(0.95, 'Converting to MP3...')
            mp3_path = str(cls.get_file_path(file_id, 'mp3'))
            soundfont = getattr(settings, 'MIDI_SOUNDFONT', None)
            success = midi_to_mp3(midi_path, mp3_path, soundfont)
            if success:
                result['mp3_path'] = mp3_path

        if output_format == 'mp3' and 'mp3_path' in result:
            os.remove(midi_path)
            del result['midi_path']

        logger.info(f"Cover complete: {result}")
        return result

    @classmethod
    def save_uploaded_prompt(cls, uploaded_file) -> str:
        """
        Save an uploaded MIDI file to a temporary location.

        Returns:
            Path to the saved file
        """
        # Create temp file with .mid extension
        fd, path = tempfile.mkstemp(suffix='.mid')
        try:
            with os.fdopen(fd, 'wb') as f:
                for chunk in uploaded_file.chunks():
                    f.write(chunk)
        except Exception:
            os.close(fd)
            raise
        return path

    @classmethod
    def cleanup_temp_file(cls, path: str):
        """Remove a temporary file."""
        try:
            if path and os.path.exists(path):
                os.remove(path)
        except Exception as e:
            logger.warning(f"Failed to cleanup temp file {path}: {e}")

    @classmethod
    def file_exists(cls, file_id: str, extension: str = 'mid') -> bool:
        """Check if a generated file exists."""
        return cls.get_file_path(file_id, extension).exists()

    @classmethod
    def get_file_for_download(cls, file_id: str) -> tuple | None:
        """
        Get file path and content type for download.

        Returns:
            Tuple of (file_path, content_type) or None if not found
        """
        # Check for MIDI
        midi_path = cls.get_file_path(file_id, 'mid')
        if midi_path.exists():
            return str(midi_path), 'audio/midi'

        # Check for MP3
        mp3_path = cls.get_file_path(file_id, 'mp3')
        if mp3_path.exists():
            return str(mp3_path), 'audio/mpeg'

        return None
