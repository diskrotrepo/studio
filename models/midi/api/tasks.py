"""
Celery tasks for async MIDI generation, pretokenization, and training.
"""

import logging
import re
import subprocess
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path
from asgiref.sync import async_to_sync
from celery import shared_task
from channels.layers import get_channel_layer

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Training log line parsers
# ---------------------------------------------------------------------------
_RE_EPOCH_LOSS = re.compile(
    r'Epoch\s+(\d+)\s+-\s+train loss:\s+([\d.]+)(?:,\s+val loss:\s+([\d.]+))?'
)
_RE_LR_GRAD = re.compile(
    r'lr:\s+([\d.eE+-]+)\s+\|\s+grad_norm:\s+avg=([\d.]+),\s+max=([\d.]+)'
    r'\s+\|\s+non-pad:\s+([\d.]+)%'
    r'(?:\s+\|\s+skipped_steps:\s+(\d+))?'
)
_RE_TIME_THROUGHPUT = re.compile(
    r'time:\s+([\d.]+)s\s+train,\s+([\d.]+)s\s+val\s+\|\s+throughput:\s+([\d,]+)\s+tok/s'
)
_RE_GPU_MEM = re.compile(r'GPU peak memory:\s+([\d.]+)GB')
_RE_HEALTH = re.compile(
    r'health:\s+phase=(\w+)\s+\|\s+ppl=([\d.]+|inf)'
    r'(?:\s+\|\s+delta=([+\-]?[\d.]+)\s+\(([+\-]?[\d.]+)%\)\s+([v^]))?'
    r'(?:\s+\|\s+5ep_trend=([+\-]?[\d.]+)/ep)?'
    r'\s+\|\s+ep=(\d+)/(\d+)\s+\((\d+)%\)'
    r'(?:\s+\|\s+flags:\s+(.+))?'
)


def _notify_task_update(task_id, status_data):
    """Push a task status update to all WebSocket subscribers."""
    channel_layer = get_channel_layer()
    if channel_layer is None:
        return
    async_to_sync(channel_layer.group_send)(
        f'task_{task_id}',
        {
            'type': 'task_status_update',
            'data': status_data,
        },
    )


@shared_task(bind=True, max_retries=0)
def generate_single_track_task(
    self,
    tags=None,
    duration=60,
    bpm=120,
    temperature=1.0,
    top_k=50,
    top_p=0.95,
    repetition_penalty=1.2,
    humanize=None,
    output_format='midi',
    seed=None,
    prompt_path=None,
    extend_from=None,
    model_name="default",
):
    """
    Async task for single-track generation.

    Returns:
        dict with file_id and paths
    """
    from api.services import GenerationService

    task_id = self.request.id
    logger.info(f"Starting single-track generation task: {task_id}")
    _notify_task_update(task_id, {'task_id': task_id, 'status': 'processing'})

    def _progress(progress, message):
        _notify_task_update(task_id, {
            'task_id': task_id,
            'status': 'processing',
            'progress': round(progress, 3),
            'message': message,
        })

    try:
        result = GenerationService.generate_single_track(
            tags=tags,
            duration=duration,
            bpm=bpm,
            temperature=temperature,
            top_k=top_k,
            top_p=top_p,
            repetition_penalty=repetition_penalty,
            humanize=humanize,
            output_format=output_format,
            seed=seed,
            prompt_path=prompt_path,
            extend_from=extend_from,
            progress_callback=_progress,
            model_name=model_name,
        )

        if prompt_path:
            GenerationService.cleanup_temp_file(prompt_path)

        logger.info(f"Task {task_id} completed: {result['file_id']}")

        status_data = {'task_id': task_id, 'status': 'complete'}
        file_id = result.get('file_id')
        if result.get('midi_path'):
            status_data['download_url'] = f'/api/download/{file_id}/'
        if result.get('mp3_path'):
            status_data['mp3_download_url'] = f'/api/download/{file_id}.mp3/'
        if result.get('expires_at'):
            status_data['expires_at'] = result['expires_at']
        _notify_task_update(task_id, status_data)

        return result

    except Exception as e:
        logger.exception(f"Task {task_id} failed: {e}")
        if prompt_path:
            GenerationService.cleanup_temp_file(prompt_path)
        _notify_task_update(task_id, {
            'task_id': task_id,
            'status': 'failed',
            'error': str(e),
        })
        raise


@shared_task(bind=True, max_retries=0)
def generate_multitrack_task(
    self,
    num_tracks=4,
    track_types=None,
    instruments=None,
    tags=None,
    duration=60,
    bpm=120,
    temperature=1.0,
    top_k=50,
    top_p=0.95,
    repetition_penalty=1.2,
    humanize=None,
    output_format='midi',
    seed=None,
    model_name="default",
):
    """
    Async task for multi-track generation.

    Returns:
        dict with file_id and paths
    """
    from api.services import GenerationService

    task_id = self.request.id
    logger.info(f"Starting multitrack generation task: {task_id}")
    _notify_task_update(task_id, {'task_id': task_id, 'status': 'processing'})

    def _progress(progress, message):
        _notify_task_update(task_id, {
            'task_id': task_id,
            'status': 'processing',
            'progress': round(progress, 3),
            'message': message,
        })

    try:
        result = GenerationService.generate_multitrack(
            num_tracks=num_tracks,
            track_types=track_types,
            instruments=instruments,
            tags=tags,
            duration=duration,
            bpm=bpm,
            temperature=temperature,
            top_k=top_k,
            top_p=top_p,
            repetition_penalty=repetition_penalty,
            humanize=humanize,
            output_format=output_format,
            seed=seed,
            progress_callback=_progress,
            model_name=model_name,
        )

        logger.info(f"Task {task_id} completed: {result['file_id']}")

        status_data = {'task_id': task_id, 'status': 'complete'}
        file_id = result.get('file_id')
        if result.get('midi_path'):
            status_data['download_url'] = f'/api/download/{file_id}/'
        if result.get('mp3_path'):
            status_data['mp3_download_url'] = f'/api/download/{file_id}.mp3/'
        if result.get('expires_at'):
            status_data['expires_at'] = result['expires_at']
        _notify_task_update(task_id, status_data)

        return result

    except Exception as e:
        logger.exception(f"Task {task_id} failed: {e}")
        _notify_task_update(task_id, {
            'task_id': task_id,
            'status': 'failed',
            'error': str(e),
        })
        raise


@shared_task(bind=True, max_retries=0)
def add_track_task(
    self,
    prompt_path,
    track_type='melody',
    instrument=None,
    tags=None,
    duration=60,
    bpm=120,
    temperature=1.0,
    top_k=50,
    top_p=0.95,
    repetition_penalty=1.2,
    humanize=None,
    output_format='midi',
    seed=None,
    model_name="default",
):
    """
    Async task for adding a track to an existing MIDI file.

    Returns:
        dict with file_id and paths
    """
    from api.services import GenerationService

    task_id = self.request.id
    logger.info(f"Starting add-track task: {task_id}")
    _notify_task_update(task_id, {'task_id': task_id, 'status': 'processing'})

    def _progress(progress, message):
        _notify_task_update(task_id, {
            'task_id': task_id,
            'status': 'processing',
            'progress': round(progress, 3),
            'message': message,
        })

    try:
        result = GenerationService.add_track(
            prompt_path=prompt_path,
            track_type=track_type,
            instrument=instrument,
            tags=tags,
            duration=duration,
            bpm=bpm,
            temperature=temperature,
            top_k=top_k,
            top_p=top_p,
            repetition_penalty=repetition_penalty,
            humanize=humanize,
            output_format=output_format,
            seed=seed,
            progress_callback=_progress,
            model_name=model_name,
        )

        GenerationService.cleanup_temp_file(prompt_path)

        logger.info(f"Task {task_id} completed: {result['file_id']}")

        status_data = {'task_id': task_id, 'status': 'complete'}
        file_id = result.get('file_id')
        if result.get('midi_path'):
            status_data['download_url'] = f'/api/download/{file_id}/'
        if result.get('mp3_path'):
            status_data['mp3_download_url'] = f'/api/download/{file_id}.mp3/'
        if result.get('expires_at'):
            status_data['expires_at'] = result['expires_at']
        _notify_task_update(task_id, status_data)

        return result

    except Exception as e:
        logger.exception(f"Task {task_id} failed: {e}")
        GenerationService.cleanup_temp_file(prompt_path)
        _notify_task_update(task_id, {
            'task_id': task_id,
            'status': 'failed',
            'error': str(e),
        })
        raise


# ---------------------------------------------------------------------------
# Pretokenize
# ---------------------------------------------------------------------------

@shared_task(bind=True, max_retries=0, soft_time_limit=None, time_limit=None)
def pretokenize_task(
    self,
    midi_dir='midi_files',
    output='checkpoints/token_cache.pkl',
    single_track=False,
    use_tags=True,
    skip_validation=False,
    validate_only=False,
    max_tracks=16,
    workers=None,
    checkpoint_interval=500,
    metadata=None,
    max_files=None,
):
    """
    Async task for pre-tokenizing MIDI files.

    Runs the pretokenize CLI as a subprocess and streams progress.
    """
    task_id = self.request.id
    logger.info(f"Starting pretokenize task: {task_id}")
    _notify_task_update(task_id, {
        'task_id': task_id, 'status': 'processing',
        'message': 'Starting pretokenization...',
    })

    cmd = [sys.executable, '-m', 'midi.data.pretokenize',
           '--midi-dir', midi_dir,
           '--output', output,
           '--checkpoint-interval', str(checkpoint_interval),
           '--max-tracks', str(max_tracks)]

    if single_track:
        cmd.append('--single-track')
    if not use_tags:
        cmd.append('--no-tags')
    if skip_validation:
        cmd.append('--skip-validation')
    if validate_only:
        cmd.append('--validate-only')
    if workers is not None:
        cmd.extend(['--workers', str(workers)])
    if metadata:
        cmd.extend(['--metadata', metadata])
    if max_files is not None:
        cmd.extend(['--max-files', str(max_files)])

    try:
        process = subprocess.Popen(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, bufsize=1,
        )

        output_lines = []
        for line in process.stdout:
            line = line.rstrip()
            output_lines.append(line)
            logger.debug(f"[pretokenize] {line}")
            _notify_task_update(task_id, {
                'task_id': task_id,
                'status': 'processing',
                'message': line,
            })

        process.wait()
        if process.returncode != 0:
            error_msg = '\n'.join(output_lines[-10:])
            raise RuntimeError(
                f"Pretokenization failed (exit {process.returncode}): {error_msg}"
            )

        logger.info(f"Pretokenize task {task_id} completed")
        _notify_task_update(task_id, {
            'task_id': task_id,
            'status': 'complete',
            'message': 'Pretokenization complete',
        })
        return {'status': 'complete'}

    except Exception as e:
        logger.exception(f"Pretokenize task {task_id} failed: {e}")
        _notify_task_update(task_id, {
            'task_id': task_id,
            'status': 'failed',
            'error': str(e),
        })
        raise


# ---------------------------------------------------------------------------
# Training
# ---------------------------------------------------------------------------

@shared_task(bind=True, max_retries=0, soft_time_limit=None, time_limit=None)
def training_task(
    self,
    midi_dir='midi_files',
    checkpoint_dir='checkpoints',
    config=None,
    epochs=None,
    batch_size=None,
    lr=None,
    grad_accum=None,
    load_from=None,
    finetune=False,
    freeze_layers=0,
    lora=False,
    lora_rank=8,
    lora_alpha=16.0,
    no_warmup=False,
    debug=False,
    max_files=None,
    # Advanced config overrides
    d_model=None,
    n_heads=None,
    n_layers=None,
    seq_length=None,
    val_split=None,
    early_stopping_patience=None,
    warmup_pct=None,
    scheduler=None,
    dropout=None,
    weight_decay=None,
    grad_clip_norm=None,
    use_tags=None,
    use_compile=None,
):
    """
    Async task for training a MIDI model.

    Runs the training CLI as a subprocess and streams progress.
    """
    import json
    import tempfile
    from pathlib import Path

    task_id = self.request.id
    logger.info(f"Starting training task: {task_id}")
    _notify_task_update(task_id, {
        'task_id': task_id, 'status': 'processing',
        'message': 'Starting training...',
    })

    # Merge advanced overrides into config JSON
    config_path = config
    advanced_overrides = {
        k: v for k, v in {
            'd_model': d_model, 'n_heads': n_heads, 'n_layers': n_layers,
            'seq_length': seq_length, 'val_split': val_split,
            'early_stopping_patience': early_stopping_patience,
            'warmup_pct': warmup_pct, 'scheduler': scheduler,
            'dropout': dropout, 'weight_decay': weight_decay,
            'grad_clip_norm': grad_clip_norm, 'use_tags': use_tags,
            'use_compile': use_compile,
        }.items() if v is not None
    }

    temp_config_file = None
    if advanced_overrides:
        base = {}
        if config_path:
            try:
                with open(config_path) as f:
                    base = {k: v for k, v in json.load(f).items()
                            if not k.startswith('_')}
            except Exception:
                pass
        base.update(advanced_overrides)
        temp_config_file = tempfile.NamedTemporaryFile(
            mode='w', suffix='.json', delete=False, prefix='train_config_',
        )
        json.dump(base, temp_config_file)
        temp_config_file.close()
        config_path = temp_config_file.name

    cmd = [sys.executable, '-m', 'midi.training.cli',
           '--midi-dir', midi_dir,
           '--checkpoint-dir', checkpoint_dir]

    if config_path:
        cmd.extend(['--config', config_path])
    if epochs is not None:
        cmd.extend(['--epochs', str(epochs)])
    if batch_size is not None:
        cmd.extend(['--batch-size', str(batch_size)])
    if lr is not None:
        cmd.extend(['--lr', str(lr)])
    if grad_accum is not None:
        cmd.extend(['--grad-accum', str(grad_accum)])
    if load_from:
        cmd.extend(['--load-from', load_from])
    if finetune:
        cmd.append('--finetune')
    if freeze_layers > 0:
        cmd.extend(['--freeze-layers', str(freeze_layers)])
    if lora:
        cmd.append('--lora')
        cmd.extend(['--lora-rank', str(lora_rank)])
        cmd.extend(['--lora-alpha', str(lora_alpha)])
    if no_warmup:
        cmd.append('--no-warmup')
    if debug:
        cmd.append('--debug')
    if max_files is not None:
        cmd.extend(['--max-files', str(max_files)])

    try:
        process = subprocess.Popen(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, bufsize=1,
        )

        output_lines = []
        metrics = {}
        for line in process.stdout:
            line = line.rstrip()
            output_lines.append(line)
            logger.debug(f"[training] {line}")

            progress = None
            send_metrics = False

            # Parse epoch + losses (resets metrics for new epoch)
            m = _RE_EPOCH_LOSS.search(line)
            if m:
                current_epoch = int(m.group(1))
                metrics = {
                    'epoch': current_epoch,
                    'total_epochs': epochs or 0,
                    'train_loss': float(m.group(2)),
                }
                if m.group(3):
                    metrics['val_loss'] = float(m.group(3))
                if epochs:
                    progress = current_epoch / epochs

            # Parse lr / grad_norm / non-pad
            m = _RE_LR_GRAD.search(line)
            if m:
                metrics['lr'] = m.group(1)
                metrics['grad_norm_avg'] = float(m.group(2))
                metrics['grad_norm_max'] = float(m.group(3))
                metrics['non_pad_pct'] = float(m.group(4))
                if m.group(5):
                    metrics['skipped_steps'] = int(m.group(5))

            # Parse time / throughput
            m = _RE_TIME_THROUGHPUT.search(line)
            if m:
                metrics['train_time_s'] = float(m.group(1))
                metrics['val_time_s'] = float(m.group(2))
                metrics['throughput_tok_s'] = int(m.group(3).replace(',', ''))

            # Parse GPU memory
            m = _RE_GPU_MEM.search(line)
            if m:
                metrics['gpu_mem_gb'] = float(m.group(1))

            # Parse health (last line per epoch — triggers metrics push)
            m = _RE_HEALTH.search(line)
            if m:
                metrics['phase'] = m.group(1)
                ppl_str = m.group(2)
                metrics['perplexity'] = (
                    float(ppl_str) if ppl_str != 'inf' else None
                )
                if m.group(3):
                    metrics['loss_delta'] = float(m.group(3))
                    metrics['loss_delta_pct'] = float(m.group(4))
                    metrics['loss_direction'] = m.group(5)
                if m.group(6):
                    metrics['trend_5ep'] = float(m.group(6))
                flags_str = m.group(10)
                metrics['flags'] = (
                    [f.strip() for f in flags_str.split(',')]
                    if flags_str else []
                )
                send_metrics = True

            update = {
                'task_id': task_id,
                'status': 'processing',
                'message': line,
            }
            if progress is not None:
                update['progress'] = round(progress, 3)
            if send_metrics and metrics:
                update['metrics'] = metrics
            _notify_task_update(task_id, update)

        process.wait()
        if process.returncode != 0:
            error_msg = '\n'.join(output_lines[-10:])
            raise RuntimeError(
                f"Training failed (exit {process.returncode}): {error_msg}"
            )

        logger.info(f"Training task {task_id} completed")
        complete_data = {
            'task_id': task_id,
            'status': 'complete',
            'message': 'Training complete',
        }
        if metrics:
            complete_data['metrics'] = metrics

        # Read training_summary.json if available
        summary_path = Path(checkpoint_dir) / 'training_summary.json'
        if summary_path.exists():
            try:
                with open(summary_path) as f:
                    complete_data['training_summary'] = json.load(f)
            except Exception:
                pass

        _notify_task_update(task_id, complete_data)
        return {'status': 'complete', 'checkpoint_dir': checkpoint_dir}

    except Exception as e:
        logger.exception(f"Training task {task_id} failed: {e}")
        failed_data = {
            'task_id': task_id,
            'status': 'failed',
            'error': str(e),
        }
        if metrics:
            failed_data['metrics'] = metrics
        _notify_task_update(task_id, failed_data)
        raise
    finally:
        if temp_config_file:
            Path(temp_config_file.name).unlink(missing_ok=True)


@shared_task(bind=True, max_retries=0)
def replace_track_task(
    self,
    prompt_path,
    track_index,
    track_type=None,
    instrument=None,
    replace_bars=None,
    tags=None,
    duration=60,
    bpm=120,
    temperature=1.0,
    top_k=50,
    top_p=0.95,
    repetition_penalty=1.2,
    humanize=None,
    output_format='midi',
    seed=None,
    model_name="default",
):
    """
    Async task for replacing a track (or bars) in an existing MIDI file.

    Returns:
        dict with file_id and paths
    """
    from api.services import GenerationService

    task_id = self.request.id
    logger.info(f"Starting replace-track task: {task_id}")
    _notify_task_update(task_id, {'task_id': task_id, 'status': 'processing'})

    def _progress(progress, message):
        _notify_task_update(task_id, {
            'task_id': task_id,
            'status': 'processing',
            'progress': round(progress, 3),
            'message': message,
        })

    try:
        result = GenerationService.replace_track(
            prompt_path=prompt_path,
            track_index=track_index,
            track_type=track_type,
            instrument=instrument,
            replace_bars=tuple(replace_bars) if replace_bars else None,
            tags=tags,
            duration=duration,
            bpm=bpm,
            temperature=temperature,
            top_k=top_k,
            top_p=top_p,
            repetition_penalty=repetition_penalty,
            humanize=humanize,
            output_format=output_format,
            seed=seed,
            progress_callback=_progress,
            model_name=model_name,
        )

        GenerationService.cleanup_temp_file(prompt_path)

        logger.info(f"Task {task_id} completed: {result['file_id']}")

        status_data = {'task_id': task_id, 'status': 'complete'}
        file_id = result.get('file_id')
        if result.get('midi_path'):
            status_data['download_url'] = f'/api/download/{file_id}/'
        if result.get('mp3_path'):
            status_data['mp3_download_url'] = f'/api/download/{file_id}.mp3/'
        if result.get('expires_at'):
            status_data['expires_at'] = result['expires_at']
        _notify_task_update(task_id, status_data)

        return result

    except Exception as e:
        logger.exception(f"Task {task_id} failed: {e}")
        GenerationService.cleanup_temp_file(prompt_path)
        _notify_task_update(task_id, {
            'task_id': task_id,
            'status': 'failed',
            'error': str(e),
        })
        raise


@shared_task(bind=True, max_retries=0, soft_time_limit=None, time_limit=None)
def download_training_data_task(
    self,
    output_dir='midi_files',
):
    """
    Download training data zip from GCS and extract it.
    """
    task_id = self.request.id
    url = os.environ.get('MIDI_TRAINING_DATA_URL', 'https://storage.googleapis.com/YOUR_BUCKET/midi_files.zip')
    logger.info(f"Starting download task: {task_id}")
    _notify_task_update(task_id, {
        'task_id': task_id, 'status': 'processing',
        'message': 'Starting download...',
    })

    tmp_path = None
    try:
        # Download with progress
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req) as resp:
            total = int(resp.headers.get('Content-Length', 0))
            tmp = tempfile.NamedTemporaryFile(
                delete=False, suffix='.zip', prefix='training_data_',
            )
            tmp_path = tmp.name
            downloaded = 0
            chunk_size = 1024 * 1024  # 1 MB

            while True:
                chunk = resp.read(chunk_size)
                if not chunk:
                    break
                tmp.write(chunk)
                downloaded += len(chunk)
                if total > 0:
                    pct = downloaded / total
                    mb_done = downloaded / (1024 * 1024)
                    mb_total = total / (1024 * 1024)
                    _notify_task_update(task_id, {
                        'task_id': task_id,
                        'status': 'processing',
                        'progress': round(pct * 0.8, 3),  # 0-80% for download
                        'message': f'Downloading... {mb_done:.0f}/{mb_total:.0f} MB',
                    })
            tmp.close()

        # Extract
        _notify_task_update(task_id, {
            'task_id': task_id,
            'status': 'processing',
            'progress': 0.85,
            'message': 'Extracting files...',
        })

        out = Path(output_dir)
        out.mkdir(parents=True, exist_ok=True)

        with zipfile.ZipFile(tmp_path) as zf:
            members = [m for m in zf.namelist()
                       if not m.startswith('__MACOSX/') and not m.startswith('._')]
            zf.extractall(out, members=members)

        # Cleanup zip
        Path(tmp_path).unlink(missing_ok=True)
        tmp_path = None

        logger.info(f"Download task {task_id} completed")
        _notify_task_update(task_id, {
            'task_id': task_id,
            'status': 'complete',
            'progress': 1.0,
            'message': f'Training data extracted to {output_dir}',
        })
        return {'status': 'complete', 'output_dir': output_dir}

    except Exception as e:
        logger.exception(f"Download task {task_id} failed: {e}")
        if tmp_path:
            Path(tmp_path).unlink(missing_ok=True)
        _notify_task_update(task_id, {
            'task_id': task_id,
            'status': 'failed',
            'error': str(e),
        })
        raise


# ---------------------------------------------------------------------------
# Diagnosis
# ---------------------------------------------------------------------------

@shared_task(bind=True, max_retries=0, soft_time_limit=None, time_limit=None)
def diagnosis_task(
    self,
    command='all',
    cache='checkpoints/token_cache.pkl',
    tokenizer=None,
    json_report=None,
    checkpoint='checkpoints/best_model.pt',
    samples=3,
    seed=42,
    checkpoint_dir='checkpoints',
):
    """
    Async task for running pipeline diagnostics.

    Runs the diagnose CLI as a subprocess and streams output.
    """
    task_id = self.request.id
    logger.info(f"Starting diagnosis task: {task_id} (command={command})")
    _notify_task_update(task_id, {
        'task_id': task_id, 'status': 'processing',
        'message': f'Starting diagnosis ({command})...',
    })

    cmd = [sys.executable, '-m', 'midi.diagnose', command]

    if command == 'tokens':
        cmd.extend(['--cache', cache])
        if tokenizer:
            cmd.extend(['--tokenizer', tokenizer])
        if json_report:
            cmd.extend(['--json', json_report])
    elif command == 'generation':
        cmd.extend(['--checkpoint', checkpoint])
        if tokenizer:
            cmd.extend(['--tokenizer', tokenizer])
        cmd.extend(['--samples', str(samples)])
        cmd.extend(['--seed', str(seed)])
    elif command == 'all':
        cmd.extend(['--checkpoint-dir', checkpoint_dir])
        cmd.extend(['--seed', str(seed)])

    try:
        process = subprocess.Popen(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, bufsize=1,
        )

        output_lines = []
        for line in process.stdout:
            line = line.rstrip()
            output_lines.append(line)
            logger.debug(f"[diagnosis] {line}")
            _notify_task_update(task_id, {
                'task_id': task_id,
                'status': 'processing',
                'message': line,
                'output': list(output_lines),
            })

        process.wait()
        if process.returncode != 0:
            error_msg = '\n'.join(output_lines[-10:])
            raise RuntimeError(
                f"Diagnosis failed (exit {process.returncode}): {error_msg}"
            )

        logger.info(f"Diagnosis task {task_id} completed")
        _notify_task_update(task_id, {
            'task_id': task_id,
            'status': 'complete',
            'message': 'Diagnosis complete',
            'output': output_lines,
        })
        return {'status': 'complete'}

    except Exception as e:
        logger.exception(f"Diagnosis task {task_id} failed: {e}")
        _notify_task_update(task_id, {
            'task_id': task_id,
            'status': 'failed',
            'error': str(e),
            'output': output_lines,
        })
        raise


@shared_task(bind=True, max_retries=0)
def cover_task(
    self,
    prompt_path,
    num_tracks=None,
    track_types=None,
    instruments=None,
    tags=None,
    duration=60,
    bpm=120,
    temperature=1.0,
    top_k=50,
    top_p=0.95,
    repetition_penalty=1.2,
    humanize=None,
    output_format='midi',
    seed=None,
    model_name="default",
):
    """
    Async task for generating a cover of an existing MIDI file.

    Returns:
        dict with file_id and paths
    """
    from api.services import GenerationService

    task_id = self.request.id
    logger.info(f"Starting cover task: {task_id}")
    _notify_task_update(task_id, {'task_id': task_id, 'status': 'processing'})

    def _progress(progress, message):
        _notify_task_update(task_id, {
            'task_id': task_id,
            'status': 'processing',
            'progress': round(progress, 3),
            'message': message,
        })

    try:
        result = GenerationService.cover(
            prompt_path=prompt_path,
            num_tracks=num_tracks,
            track_types=track_types,
            instruments=instruments,
            tags=tags,
            duration=duration,
            bpm=bpm,
            temperature=temperature,
            top_k=top_k,
            top_p=top_p,
            repetition_penalty=repetition_penalty,
            humanize=humanize,
            output_format=output_format,
            seed=seed,
            progress_callback=_progress,
            model_name=model_name,
        )

        GenerationService.cleanup_temp_file(prompt_path)

        logger.info(f"Task {task_id} completed: {result['file_id']}")

        status_data = {'task_id': task_id, 'status': 'complete'}
        file_id = result.get('file_id')
        if result.get('midi_path'):
            status_data['download_url'] = f'/api/download/{file_id}/'
        if result.get('mp3_path'):
            status_data['mp3_download_url'] = f'/api/download/{file_id}.mp3/'
        if result.get('expires_at'):
            status_data['expires_at'] = result['expires_at']
        _notify_task_update(task_id, status_data)

        return result

    except Exception as e:
        logger.exception(f"Task {task_id} failed: {e}")
        GenerationService.cleanup_temp_file(prompt_path)
        _notify_task_update(task_id, {
            'task_id': task_id,
            'status': 'failed',
            'error': str(e),
        })
        raise
