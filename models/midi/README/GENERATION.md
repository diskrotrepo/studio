# Generation

## Basic Usage

```bash
# Generate 60 seconds from scratch
python3 generate.py

# Control duration and tempo
python3 generate.py --duration 120     # Generate 2 minutes
python3 generate.py --bpm 140          # Faster tempo

# Adjust creativity
python3 generate.py --creativity 0.8   # More conservative
python3 generate.py --creativity 1.2   # More experimental

# Use style tags (genre, mood, tempo)
python3 generate.py --tags "jazz happy"
python3 generate.py --tags "classical melancholic slow"
python3 generate.py --tags "list"      # Show all available tags

# Continue from existing MIDI
python3 generate.py --prompt some_song.mid

# Extend existing MIDI
python3 generate.py --prompt song.mid --extend-from 30    # Override: keep first 30s, regenerate rest
python3 generate.py --prompt song.mid --extend-from -30   # Append: add to end, use last 30s as context

# Reproducible generation
python3 generate.py --seed 42

# Combine options
python3 generate.py --duration 120 --bpm 140 --tags "electronic energetic" --creativity 1.1
```

Output files are saved as `<uuid>.mid` by default, or specify with `--output filename.mid`.

## Multi-Track Generation

Generate music with up to 16 instruments playing together (supports ~6 minute songs):

```bash
# Generate with 3-8 random tracks
python3 generate.py --multitrack

# Specify number of tracks (up to 16)
python3 generate.py --multitrack --num-tracks 8

# Customize track types
python3 generate.py --multitrack --track-types "melody,bass,drums,strings,brass"

# Specify instruments (MIDI program numbers)
python3 generate.py --multitrack --instruments "0,33,40,56"  # Piano, Bass, Strings, Trumpet

# Combine with rich conditioning tags
python3 generate.py --multitrack --tags "jazz swing expressive full_arrangement" --num-tracks 8

# Use musical attribute tags for fine control
python3 generate.py --multitrack --tags "minor 3_4 moderate legato vintage"
```

**Track types (15):** melody, bass, chords, drums, percussion, pad, strings, lead, organ, brass, woodwind, synth, choir, fx, other

**Common MIDI instruments:** 0=Piano, 24=Guitar, 33=Bass, 40=Violin, 56=Trumpet, 73=Flute

## Available Tags

- **Genre:** rock, metal, pop, electronic, hip_hop, r&b_soul, jazz, classical, country, blues, reggae, latin, world, soundtrack, easy_listening, ambient, folk, unknown
- **Mood:** happy, sad, energetic, calm, dark, uplifting, melancholic, intense
- **Tempo:** slow, medium, fast
- **Key:** major, minor (auto-detected from MIDI)
- **Time Signature:** 4_4, 3_4, 6_8, 2_4, 5_4, 7_8, 12_8, other_time (auto-detected)
- **Density:** sparse, moderate, dense (notes per beat)
- **Dynamics:** soft, moderate_dynamics, loud, dynamic (velocity analysis)
- **Length:** short, medium_length, long (piece duration)
- **Register:** low_register, mid_register, high_register, wide_range (pitch analysis)
- **Arrangement:** solo, duo, small_ensemble, full_arrangement (track count)
- **Rhythm:** straight, swing, syncopated, complex_rhythm (onset analysis)
- **Harmony:** simple_harmony, moderate_harmony, complex_harmony (pitch class count)
- **Articulation:** legato, staccato, mixed_articulation (note gaps)
- **Expression:** mechanical, expressive, highly_expressive (velocity variance + pitch bends)
- **Era:** vintage, modern, contemporary (instrument programs)
- **Artist:** automatically discovered from folder names (see below)

## Artist Tags

If your MIDI files are organized by artist folder, the model automatically learns artist-specific styles:

```
midi_files/
├── artist_a/
│   └── track_01.mid
├── artist_b/
│   └── track_02.mid
└── artist_c/
    └── track_03.mid
```

During pre-tokenization, artists are discovered and printed:
```
Discovered 3 artists: artist_a, artist_b, artist_c
```

Generate in a specific artist's style:
```bash
# Using artist: prefix
python3 generate.py --tags "artist:artist_a classical"

# Or just the artist name
python3 generate.py --tags "artist_b jazz"

# Combine with other tags
python3 generate.py --tags "artist_c melancholic slow"
```

## All Generation Options

| Argument | Default | Description |
|----------|---------|-------------|
| `--checkpoint` | `checkpoints/best_model.pt` | Path to model checkpoint |
| `--lora-adapter` | None | Path to LoRA adapter file (trained with --lora) |
| `--prompt` | None | MIDI file to continue from |
| `--extend-from` | None | Time position to extend from (positive=override, negative=append) |
| `--tags` | None | Style tags (e.g., "jazz happy fast") |
| `--output` | `<uuid>.mid` | Output file path |
| `--duration` | 60 | Duration in seconds |
| `--bpm` | 120 | Target tempo in BPM |
| `--creativity` | 1.0 | Creativity level (higher = more experimental) |
| `--top-k` | 50 | Top-k sampling (0 to disable) |
| `--top-p` | 0.95 | Nucleus sampling threshold |
| `--seed` | None | Random seed for reproducibility |
| `--mp3` | False | Also export as MP3 audio |
| `--soundfont` | Auto-detect | Path to SoundFont file for MP3 export |
| `--multitrack` | False | Generate multi-track music |
| `--num-tracks` | Auto (3-8) | Number of tracks to generate |
| `--track-types` | Auto | Comma-separated track types (melody,bass,chords,drums) |
| `--instruments` | Auto | Comma-separated MIDI program numbers |

## MP3 Export

To export generated MIDI as MP3 audio, you need FluidSynth and a SoundFont installed:

**Ubuntu/Debian:**
```bash
sudo apt install fluidsynth fluid-soundfont-gm
```

**macOS:**
```bash
brew install fluid-synth
```

Then generate with MP3 output:
```bash
python3 generate.py --mp3
```

If the SoundFont isn't detected automatically, specify it:
```bash
python3 generate.py --mp3 --soundfont /usr/share/sounds/sf2/FluidR3_GM.sf2
```
