"""
API views for MIDI generation endpoints.
"""

import logging
import os
from datetime import datetime
from pathlib import Path

from django.http import FileResponse, Http404
from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.parsers import JSONParser, MultiPartParser, FormParser
from celery.result import AsyncResult

from .serializers import (
    GenerateRequestSerializer,
    GenerateWithPromptRequestSerializer,
    MultitrackGenerateRequestSerializer,
    AddTrackRequestSerializer,
    ReplaceTrackRequestSerializer,
    CoverRequestSerializer,
    ConvertRequestSerializer,
    PretokenizeRequestSerializer,
    DiagnosisRequestSerializer,
    TrainingRequestSerializer,
    AutotuneRequestSerializer,
    ScanRequestSerializer,
    StageRequestSerializer,
    BrowseRequestSerializer,
    DownloadDataRequestSerializer,
    TaskResponseSerializer,
    TaskStatusSerializer,
)
from .services import GenerationService
from .tasks import (
    generate_single_track_task,
    generate_multitrack_task,
    add_track_task,
    replace_track_task,
    cover_task,
    pretokenize_task,
    diagnosis_task,
    training_task,
    download_training_data_task,
)

logger = logging.getLogger(__name__)


class GenerateView(APIView):
    """
    Submit a single-track MIDI generation task.

    POST /api/generate/
    """
    parser_classes = [JSONParser, MultiPartParser, FormParser]

    def post(self, request):
        # Use file upload serializer if file is present
        if request.FILES.get('prompt_midi'):
            serializer = GenerateWithPromptRequestSerializer(data=request.data)
        else:
            serializer = GenerateRequestSerializer(data=request.data)

        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        # Handle uploaded prompt file
        prompt_path = None
        if 'prompt_midi' in data and data['prompt_midi']:
            prompt_path = GenerationService.save_uploaded_prompt(data['prompt_midi'])

        # Submit async task
        task = generate_single_track_task.delay(
            tags=data.get('tags'),
            duration=data.get('duration', 60),
            bpm=data.get('bpm', 120),
            temperature=data.get('temperature', 1.0),
            top_k=data.get('top_k', 50),
            top_p=data.get('top_p', 0.95),
            repetition_penalty=data.get('repetition_penalty', 1.2),
            humanize=data.get('humanize'),
            output_format='both',
            seed=data.get('seed'),
            prompt_path=prompt_path,
            extend_from=data.get('extend_from'),
            model_name=data.get('model', 'default'),
        )

        logger.info(f"Submitted generation task: {task.id}")

        response_data = {
            'task_id': task.id,
            'status': 'pending',
            'status_url': f'/api/tasks/{task.id}/',
        }

        return Response(response_data, status=status.HTTP_202_ACCEPTED)


class MultitrackGenerateView(APIView):
    """
    Submit a multi-track MIDI generation task.

    POST /api/generate/multitrack/
    """
    parser_classes = [JSONParser]

    def post(self, request):
        serializer = MultitrackGenerateRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        # Submit async task
        task = generate_multitrack_task.delay(
            num_tracks=data.get('num_tracks', 4),
            track_types=data.get('track_types'),
            instruments=data.get('instruments'),
            tags=data.get('tags'),
            duration=data.get('duration', 60),
            bpm=data.get('bpm', 120),
            temperature=data.get('temperature', 1.0),
            top_k=data.get('top_k', 50),
            top_p=data.get('top_p', 0.95),
            repetition_penalty=data.get('repetition_penalty', 1.2),
            humanize=data.get('humanize'),
            output_format='both',
            seed=data.get('seed'),
            model_name=data.get('model', 'default'),
        )

        logger.info(f"Submitted multitrack generation task: {task.id}")

        response_data = {
            'task_id': task.id,
            'status': 'pending',
            'status_url': f'/api/tasks/{task.id}/',
        }

        return Response(response_data, status=status.HTTP_202_ACCEPTED)


class AddTrackView(APIView):
    """
    Add a new track to an existing MIDI file.

    POST /api/generate/add-track/
    """
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        serializer = AddTrackRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        prompt_path = GenerationService.save_uploaded_prompt(data['prompt_midi'])

        task = add_track_task.delay(
            prompt_path=prompt_path,
            track_type=data.get('track_type', 'melody'),
            instrument=data.get('instrument'),
            tags=data.get('tags'),
            duration=data.get('duration', 60),
            bpm=data.get('bpm', 120),
            temperature=data.get('temperature', 1.0),
            top_k=data.get('top_k', 50),
            top_p=data.get('top_p', 0.95),
            repetition_penalty=data.get('repetition_penalty', 1.2),
            humanize=data.get('humanize'),
            output_format='both',
            seed=data.get('seed'),
            model_name=data.get('model', 'default'),
        )

        logger.info(f"Submitted add-track task: {task.id}")

        response_data = {
            'task_id': task.id,
            'status': 'pending',
            'status_url': f'/api/tasks/{task.id}/',
        }

        return Response(response_data, status=status.HTTP_202_ACCEPTED)


class ReplaceTrackView(APIView):
    """
    Replace a track (or bars within a track) in an existing MIDI file.

    POST /api/generate/replace-track/
    """
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        serializer = ReplaceTrackRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        prompt_path = GenerationService.save_uploaded_prompt(data['prompt_midi'])

        # Convert 1-based track_index from API to 0-based for internal use
        track_index = data['track_index'] - 1

        # Convert replace_bars from 1-based to 0-based
        replace_bars = data.get('replace_bars')
        if replace_bars:
            replace_bars = tuple(b - 1 for b in replace_bars)

        task = replace_track_task.delay(
            prompt_path=prompt_path,
            track_index=track_index,
            track_type=data.get('track_type'),
            instrument=data.get('instrument'),
            replace_bars=list(replace_bars) if replace_bars else None,
            tags=data.get('tags'),
            duration=data.get('duration', 60),
            bpm=data.get('bpm', 120),
            temperature=data.get('temperature', 1.0),
            top_k=data.get('top_k', 50),
            top_p=data.get('top_p', 0.95),
            repetition_penalty=data.get('repetition_penalty', 1.2),
            humanize=data.get('humanize'),
            output_format='both',
            seed=data.get('seed'),
            model_name=data.get('model', 'default'),
        )

        logger.info(f"Submitted replace-track task: {task.id}")

        response_data = {
            'task_id': task.id,
            'status': 'pending',
            'status_url': f'/api/tasks/{task.id}/',
        }

        return Response(response_data, status=status.HTTP_202_ACCEPTED)


class CoverView(APIView):
    """
    Generate a cover of an existing MIDI file.

    POST /api/generate/cover/
    """
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        serializer = CoverRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        prompt_path = GenerationService.save_uploaded_prompt(data['prompt_midi'])

        task = cover_task.delay(
            prompt_path=prompt_path,
            num_tracks=data.get('num_tracks'),
            track_types=data.get('track_types'),
            instruments=data.get('instruments'),
            tags=data.get('tags'),
            duration=data.get('duration', 60),
            bpm=data.get('bpm', 120),
            temperature=data.get('temperature', 1.0),
            top_k=data.get('top_k', 50),
            top_p=data.get('top_p', 0.95),
            repetition_penalty=data.get('repetition_penalty', 1.2),
            humanize=data.get('humanize'),
            output_format='both',
            seed=data.get('seed'),
            model_name=data.get('model', 'default'),
        )

        logger.info(f"Submitted cover task: {task.id}")

        response_data = {
            'task_id': task.id,
            'status': 'pending',
            'status_url': f'/api/tasks/{task.id}/',
        }

        return Response(response_data, status=status.HTTP_202_ACCEPTED)


class TaskStatusView(APIView):
    """
    Check the status of a generation task.

    GET /api/tasks/{task_id}/
    """

    def get(self, request, task_id):
        result = AsyncResult(task_id)

        response_data = {
            'task_id': task_id,
        }

        if result.state == 'PENDING':
            response_data['status'] = 'pending'

        elif result.state == 'STARTED':
            response_data['status'] = 'processing'

        elif result.state == 'SUCCESS':
            response_data['status'] = 'complete'
            task_result = result.result

            if task_result:
                file_id = task_result.get('file_id')

                if task_result.get('midi_path'):
                    response_data['download_url'] = f'/api/download/{file_id}/'

                if task_result.get('mp3_path'):
                    response_data['mp3_download_url'] = f'/api/download/{file_id}.mp3/'

                if task_result.get('expires_at'):
                    response_data['expires_at'] = task_result['expires_at']

        elif result.state == 'FAILURE':
            response_data['status'] = 'failed'
            response_data['error'] = str(result.result) if result.result else 'Unknown error'

        else:
            response_data['status'] = 'processing'

        return Response(response_data)


class DownloadView(APIView):
    """
    Download a generated file.

    GET /api/download/{file_id}/
    GET /api/download/{file_id}.mp3/
    """

    def get(self, request, file_id):
        # Check if .mp3 extension was requested
        if file_id.endswith('.mp3'):
            file_id = file_id[:-4]
            extension = 'mp3'
        else:
            extension = 'mid'

        file_path = GenerationService.get_file_path(file_id, extension)

        if not file_path.exists():
            raise Http404("File not found or expired")

        content_type = 'audio/mpeg' if extension == 'mp3' else 'audio/midi'
        filename = f"generated.{extension}"

        return FileResponse(
            open(file_path, 'rb'),
            as_attachment=True,
            filename=filename,
            content_type=content_type,
        )


class ConvertView(APIView):
    """
    Convert a MIDI file to MP3.

    POST /api/convert/
    """
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        serializer = ConvertRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        uploaded_file = serializer.validated_data['midi_file']
        midi_path = GenerationService.save_uploaded_prompt(uploaded_file)

        try:
            from midi.generation import midi_to_mp3

            file_id = GenerationService.generate_file_id()
            mp3_path = str(GenerationService.get_file_path(file_id, 'mp3'))
            from django.conf import settings
            soundfont = getattr(settings, 'MIDI_SOUNDFONT', None)

            success = midi_to_mp3(midi_path, mp3_path, soundfont)

            if not success:
                return Response(
                    {'error': 'MP3 conversion failed. Check FluidSynth and SoundFont installation.'},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR,
                )

            return Response({
                'mp3_download_url': f'/api/download/{file_id}.mp3/',
            })
        finally:
            GenerationService.cleanup_temp_file(midi_path)


class TagsView(APIView):
    """
    List available style tags.

    GET /api/tags/
    """

    def get(self, request):
        from midi.tokenizer import get_available_tags

        tags = get_available_tags()

        response_data = {
            'genres': tags.get('genres', []),
            'moods': tags.get('moods', []),
            'tempos': tags.get('tempos', []),
        }

        return Response(response_data)


class HealthView(APIView):
    """
    Health check endpoint.

    GET /api/health/
    """

    def get(self, request):
        from api.apps import ApiConfig

        health_status = {
            'status': 'ok',
            'timestamp': datetime.utcnow().isoformat(),
        }

        # Trigger model loading if needed, then report status
        try:
            ApiConfig._load_models_if_needed()
            health_status['models_loaded'] = bool(ApiConfig._models)
            health_status['device'] = str(ApiConfig._device)
            health_status['models'] = {
                name: {
                    'checkpoint': entry['checkpoint'],
                    'has_lora': entry['lora_adapter'] is not None,
                }
                for name, entry in ApiConfig._models.items()
            }
        except Exception as e:
            health_status['models_loaded'] = False
            health_status['model_error'] = str(e)

        return Response(health_status)


class InstrumentsView(APIView):
    """
    List available instruments grouped by GM category.

    GET /api/instruments/
    """

    def get(self, request):
        from midi.generation.instruments import get_categorized_instruments

        return Response({'categories': get_categorized_instruments()})


class TrackInstrumentsView(APIView):
    """
    List available instruments per track, scoped to each track's type.

    GET /api/instruments/tracks/?track_types=bass,melody,chords,drums
    GET /api/instruments/tracks/?track_types=bass,melody,chords,drums&genre=jazz
    GET /api/instruments/tracks/                  (returns all track types)
    GET /api/instruments/tracks/?genre=jazz        (returns all track types for jazz)
    """

    def get(self, request):
        from midi.generation.instruments import (
            get_track_type_instruments, GENRE_INSTRUMENT_POOLS, TRACK_TYPE_ICONS,
        )

        genre = request.query_params.get('genre')
        all_pools = get_track_type_instruments(genre)
        available_genres = sorted(GENRE_INSTRUMENT_POOLS.keys())

        raw = request.query_params.get('track_types')
        if raw:
            requested = [t.strip() for t in raw.split(',') if t.strip()]
            tracks = []
            for i, tt in enumerate(requested):
                tracks.append({
                    'track': i + 1,
                    'type': tt,
                    'icon': TRACK_TYPE_ICONS.get(tt, 'music_note'),
                    'instruments': all_pools.get(tt, []),
                })
            return Response({
                'genre': genre,
                'tracks': tracks,
                'available_genres': available_genres,
            })

        track_types = []
        for tt, instruments in all_pools.items():
            track_types.append({
                'type': tt,
                'icon': TRACK_TYPE_ICONS.get(tt, 'music_note'),
                'instruments': instruments,
            })

        return Response({
            'genre': genre,
            'track_types': track_types,
            'available_genres': available_genres,
        })


class PretokenizeView(APIView):
    """
    Submit a pretokenization task.

    POST /api/pretokenize/
    """
    parser_classes = [JSONParser]

    def post(self, request):
        serializer = PretokenizeRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        task = pretokenize_task.delay(
            midi_dir=data.get('midi_dir', 'midi_files'),
            output=data.get('output', 'checkpoints/token_cache.pkl'),
            single_track=data.get('single_track', False),
            use_tags=data.get('use_tags', True),
            skip_validation=data.get('skip_validation', False),
            validate_only=data.get('validate_only', False),
            max_tracks=data.get('max_tracks', 16),
            workers=data.get('workers'),
            checkpoint_interval=data.get('checkpoint_interval', 500),
            metadata=data.get('metadata'),
            max_files=data.get('max_files'),
        )

        logger.info(f"Submitted pretokenize task: {task.id}")

        return Response({
            'task_id': task.id,
            'status': 'pending',
            'status_url': f'/api/tasks/{task.id}/',
        }, status=status.HTTP_202_ACCEPTED)


class DiagnosisView(APIView):
    """
    Submit a pipeline diagnosis task.

    POST /api/diagnosis/
    """
    parser_classes = [JSONParser]

    def post(self, request):
        serializer = DiagnosisRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        task = diagnosis_task.delay(
            command=data.get('command', 'all'),
            cache=data.get('cache', 'checkpoints/token_cache.pkl'),
            tokenizer=data.get('tokenizer') or None,
            json_report=data.get('json_report') or None,
            checkpoint=data.get('checkpoint', 'checkpoints/best_model.pt'),
            samples=data.get('samples', 3),
            seed=data.get('seed', 42),
            checkpoint_dir=data.get('checkpoint_dir', 'checkpoints'),
        )

        logger.info(f"Submitted diagnosis task: {task.id}")

        return Response({
            'task_id': task.id,
            'status': 'pending',
            'status_url': f'/api/tasks/{task.id}/',
        }, status=status.HTTP_202_ACCEPTED)


class DataBrowseView(APIView):
    """
    Browse server-side directories.

    POST /api/data/browse/
    """
    parser_classes = [JSONParser]

    def post(self, request):
        serializer = BrowseRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        browse_path = Path(data.get('path', '.')).resolve()

        if not browse_path.is_dir():
            return Response(
                {'error': f'Directory not found: {browse_path}'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        file_extensions = data.get('file_extensions')
        ext_set = {e if e.startswith('.') else f'.{e}'
                   for e in (file_extensions or [])}

        entries = []
        file_entries = []
        try:
            for entry in sorted(browse_path.iterdir()):
                if entry.name.startswith('.'):
                    continue
                if entry.is_dir():
                    entries.append(entry.name)
                elif ext_set and entry.suffix.lower() in ext_set:
                    file_entries.append(entry.name)
        except PermissionError:
            return Response(
                {'error': f'Permission denied: {browse_path}'},
                status=status.HTTP_403_FORBIDDEN,
            )

        response = {
            'path': str(browse_path),
            'parent': str(browse_path.parent) if browse_path != browse_path.parent else None,
            'directories': entries,
        }
        if ext_set:
            response['files'] = file_entries

        return Response(response)


class DataScanView(APIView):
    """
    Scan a MIDI directory and return stats.

    POST /api/data/scan/
    """
    parser_classes = [JSONParser]

    def post(self, request):
        import json as _json

        serializer = ScanRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        midi_dir = Path(data.get('midi_dir', 'midi_files'))

        if not midi_dir.is_dir():
            return Response(
                {'error': f'Directory not found: {midi_dir}'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Load metadata if provided
        metadata = {}
        metadata_path = data.get('metadata')
        if metadata_path:
            meta_file = Path(metadata_path)
            if meta_file.is_file():
                try:
                    with open(meta_file) as fh:
                        raw = _json.load(fh)
                    metadata = raw.get('files', raw)
                except Exception:
                    pass

        midi_extensions = {'.mid', '.midi'}
        midi_files = []
        total_size = 0
        all_genres = set()
        all_moods = set()
        all_artists = set()

        for root, _dirs, files in os.walk(midi_dir):
            for f in files:
                if Path(f).suffix.lower() in midi_extensions:
                    full_path = Path(root) / f
                    try:
                        size = full_path.stat().st_size
                    except OSError:
                        continue

                    rel = str(full_path.relative_to(midi_dir))
                    entry = {
                        'relative_path': rel,
                        'size': size,
                    }

                    # Enrich with metadata (lookup by filename)
                    meta = metadata.get(f)
                    if meta:
                        genres = meta.get('genres', [])
                        moods = meta.get('moods', [])
                        artist = meta.get('artist', '')
                        entry['genres'] = genres
                        entry['moods'] = moods
                        if artist:
                            entry['artist'] = artist
                            all_artists.add(artist)
                        all_genres.update(genres)
                        all_moods.update(moods)

                    midi_files.append(entry)
                    total_size += size

            if len(midi_files) >= 100_000:
                break

        midi_files.sort(key=lambda x: x['relative_path'])

        response = {
            'file_count': len(midi_files),
            'total_size_bytes': total_size,
            'files': midi_files,
            'directory': str(midi_dir),
        }

        if metadata:
            response['available_filters'] = {
                'genres': sorted(all_genres),
                'moods': sorted(all_moods),
                'artists': sorted(all_artists),
            }

        return Response(response)


class DataStageView(APIView):
    """
    Stage selected MIDI files into a staging directory via symlinks.

    POST /api/data/stage/
    """
    parser_classes = [JSONParser]

    def post(self, request):
        import shutil

        serializer = StageRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        source_dir = Path(data['source_dir']).resolve()
        if not source_dir.is_dir():
            return Response(
                {'error': f'Source directory not found: {source_dir}'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        staging_dir = Path('staging').resolve()

        # Clear existing staging directory
        if staging_dir.exists():
            shutil.rmtree(staging_dir)
        staging_dir.mkdir(parents=True)

        staged_count = 0
        errors = []

        for rel_path in data['files']:
            src = source_dir / rel_path
            dst = staging_dir / rel_path

            if not src.is_file():
                errors.append(f'Not found: {rel_path}')
                continue

            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.symlink_to(src)
            staged_count += 1

        response = {
            'staged_dir': str(staging_dir),
            'file_count': staged_count,
        }
        if errors:
            response['errors'] = errors[:20]

        return Response(response)


class DataDownloadView(APIView):
    """
    Download training data from GCS and extract it.

    POST /api/data/download/
    """
    parser_classes = [JSONParser]

    def post(self, request):
        serializer = DownloadDataRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        task = download_training_data_task.delay(
            output_dir=data.get('output_dir', 'midi_files'),
        )

        logger.info(f"Submitted download task: {task.id}")

        return Response({
            'task_id': task.id,
            'status': 'pending',
            'status_url': f'/api/tasks/{task.id}/',
        }, status=status.HTTP_202_ACCEPTED)


class TrainingStartView(APIView):
    """
    Submit a training task.

    POST /api/training/start/
    """
    parser_classes = [JSONParser]

    def post(self, request):
        serializer = TrainingRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        task = training_task.delay(
            midi_dir=data.get('midi_dir', 'midi_files'),
            checkpoint_dir=data.get('checkpoint_dir', 'checkpoints'),
            config=data.get('config'),
            epochs=data.get('epochs'),
            batch_size=data.get('batch_size'),
            lr=data.get('lr'),
            grad_accum=data.get('grad_accum'),
            load_from=data.get('load_from'),
            finetune=data.get('finetune', False),
            freeze_layers=data.get('freeze_layers', 0),
            lora=data.get('lora', False),
            lora_rank=data.get('lora_rank', 8),
            lora_alpha=data.get('lora_alpha', 16.0),
            no_warmup=data.get('no_warmup', False),
            debug=data.get('debug', False),
            max_files=data.get('max_files'),
            d_model=data.get('d_model'),
            n_heads=data.get('n_heads'),
            n_layers=data.get('n_layers'),
            seq_length=data.get('seq_length'),
            val_split=data.get('val_split'),
            early_stopping_patience=data.get('early_stopping_patience'),
            warmup_pct=data.get('warmup_pct'),
            scheduler=data.get('scheduler'),
            dropout=data.get('dropout'),
            weight_decay=data.get('weight_decay'),
            grad_clip_norm=data.get('grad_clip_norm'),
            use_tags=data.get('use_tags'),
            use_compile=data.get('use_compile'),
        )

        logger.info(f"Submitted training task: {task.id}")

        return Response({
            'task_id': task.id,
            'status': 'pending',
            'status_url': f'/api/tasks/{task.id}/',
        }, status=status.HTTP_202_ACCEPTED)


class TrainingSummaryView(APIView):
    """
    Retrieve the training summary for a checkpoint directory.

    GET /api/training/summary/?checkpoint_dir=checkpoints
    """

    def get(self, request):
        checkpoint_dir = request.query_params.get('checkpoint_dir', 'checkpoints')
        summary_path = Path(checkpoint_dir) / 'training_summary.json'

        if not summary_path.exists():
            return Response(
                {'error': 'No training summary found', 'path': str(summary_path)},
                status=status.HTTP_404_NOT_FOUND,
            )

        import json
        try:
            with open(summary_path) as f:
                summary = json.load(f)
        except (json.JSONDecodeError, OSError) as e:
            return Response(
                {'error': f'Failed to read training summary: {e}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        return Response(summary)


class AutotuneView(APIView):
    """
    Generate an auto-tuned training config based on hardware and dataset.

    POST /api/training/autotune/
    """
    parser_classes = [JSONParser]

    def post(self, request):
        serializer = AutotuneRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        midi_dir = data.get('midi_dir', 'midi_files')
        checkpoint_dir = data.get('checkpoint_dir', 'checkpoints')
        cache_path = f"{checkpoint_dir}/token_cache.pkl"

        try:
            from midi.training.autotune import autotune
            config = autotune(
                midi_dir=midi_dir,
                cache_path=cache_path,
                quiet=True,
            )
        except ValueError as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response(config)


class ModelsView(APIView):
    """
    List available models.

    GET /api/models/
    """

    def get(self, request):
        from api.apps import ApiConfig

        try:
            models = ApiConfig.get_available_models()
        except Exception as e:
            return Response(
                {'error': f'Failed to load models: {e}'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        return Response({
            'models': models,
            'default': 'default',
        })
