# MIDI Music Generation with Transformers

A complete project for training a transformer model on MIDI music, with support for **multi-track generation** using cross-track attention.

## Quick Start

### 1. Set up environment

```bash
sudo apt install fluidsynth fluid-soundfont-gm
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 2. Get some MIDI files

Create a `midi_files/` directory and add your `.mid` files:

```bash
mkdir midi_files
# Add your .mid files here
```

**Recommended datasets:**
- [Lakh MIDI Dataset](https://colinraffel.com/projects/lmd/) (~170k files, mixed genres)
- [MAESTRO](https://magenta.tensorflow.org/datasets/maestro) (piano performances, high quality)
- [ADL Piano MIDI](https://github.com/lucasnfe/adl-piano-midi) (pop songs, piano arrangements)

### 3. Train the model

```bash
# Validate and pre-tokenize MIDI files
python3 pretokenize.py --validate-only
./scripts/delete_bad_midi.sh  # if bad files found
python3 pretokenize.py

# Auto-tune a config for your hardware and dataset
python3 -m midi.training.autotune --midi-dir midi_files --output configs/auto.json

# Train with the generated config
python3 train.py --config configs/auto.json
```

The auto-tuner detects your hardware (CUDA GPUs, Apple Silicon MPS, or CPU) and analyzes your dataset size to generate an optimized training configuration. For even more precise tuning, point it at an existing token cache:

```bash
python3 -m midi.training.autotune --cache checkpoints/token_cache.pkl --output configs/auto.json
```

You can also use a hand-crafted hardware preset instead — see [TRAINING.md](TRAINING.md) for full training options, multi-GPU setup, and hardware configs.

### 4. Generate music

```bash
# Generate 60 seconds from scratch
python3 generate.py

# With style tags
python3 generate.py --tags "jazz energetic"

# Multi-track (up to 16 instruments)
python3 generate.py --multitrack --num-tracks 8
```

See [GENERATION.md](GENERATION.md) for all generation options, multi-track details, and available tags.

### 5. Run the API server (optional)

See [API.md](API.md) for running the Django REST API with Celery task queue.

## Project Structure

```
├── train.py              # CLI entry point for training
├── pretokenize.py        # CLI entry point for pre-tokenization
├── generate.py           # CLI entry point for generation
├── midi/                 # Core Python package
│   ├── model.py          # Transformer architecture (single + multi-track, LoRA)
│   ├── tokenizer.py      # MIDI tokenization (REMI encoding) + re-exports
│   ├── tags.py           # Conditioning tag constants and discovery
│   ├── tag_inference.py  # Infer tags from MIDI content and metadata
│   ├── lastfm_tags.py    # Last.fm tag mapping to canonical tokens
│   ├── validation.py     # MIDI file validation
│   ├── batch_tokenize.py # Parallel batch tokenization
│   ├── midi_io.py        # MIDI read/write, humanize, multitrack conversion
│   ├── multitrack_utils.py # Track IDs, cross-track attention masks
│   ├── train.py          # Training loop (single GPU, distributed, LoRA)
│   ├── generate.py       # Generation (sampling, MP3 export)
│   ├── pretokenize.py    # Pre-tokenization with incremental checkpointing
│   └── organize_by_genre.py # Organize MIDI files by genre via MusicBrainz
├── api/                  # Django REST API
├── configs/              # Hardware-specific training configs
│   ├── m4_max_128gb.json # Apple M4 Max 128GB (MPS)
│   ├── a100_40gb.json    # Single NVIDIA A100 40GB
│   └── 8x_a100.json     # 8x A100 distributed training
├── tests/                # Pytest test suite
├── midi_files/           # Your training data (create this)
├── checkpoints/          # Saved models (created during training)
├── scripts/              # Utility scripts (data prep, diagnostics)
│   ├── delete_bad_midi.sh
│   ├── diagnose.py
│   ├── fetch_genres.py
│   ├── import_lastfm_tags.py
│   ├── organize_lmd_by_genre.py
│   └── propagate_artist_tags.py
└── requirements.txt      # Dependencies
```

## Documentation

- [GENERATION.md](GENERATION.md) - Generation options, multi-track, tags, MP3 export
- [TRAINING.md](TRAINING.md) - Training, pre-tokenization, configuration, multi-GPU
- [API.md](API.md) - REST API server setup and endpoints
- [HOW_IT_WORKS.md](HOW_IT_WORKS.md) - Beginner's guide to how the model works
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues and fixes
