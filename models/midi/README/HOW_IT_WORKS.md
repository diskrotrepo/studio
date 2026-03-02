# How This MIDI Generator Works

A beginner's guide to this machine learning music generator.

---

## The Big Picture

This project teaches a computer to compose music by learning patterns from existing songs.

```
                    THE COMPLETE SYSTEM
    ================================================================

    TRAINING (teach the model)          GENERATION (make new music)
    ─────────────────────────           ──────────────────────────────

         MIDI Files                          [Start Token]
              │                                    │
              ▼                                    ▼
        ┌──────────┐                         ┌──────────┐
        │Tokenizer │                         │  Model   │◄─────┐
        │(MIDI→num)│                         │(trained) │      │
        └────┬─────┘                         └────┬─────┘      │
             │                                    │            │
             ▼                                    ▼            │
        [60,16,200,45,64,...]             "Next token is       │
             │                              probably 67"       │
             ▼                                    │            │
        ┌──────────┐                              ▼            │
        │  Model   │                         [Sample it]       │
        │(learning)│                              │            │
        └────┬─────┘                              ▼            │
             │                               Add to sequence───┘
             ▼                               (repeat 512x)
        Compare prediction                        │
        vs actual next token                      ▼
             │                              ┌──────────┐
             ▼                              │Tokenizer │
        Adjust weights                      │(num→MIDI)│
        (learn pattern)                     └────┬─────┘
                                                 │
                                                 ▼
                                            New Song!
```

**Analogy:** Like teaching someone piano by showing them 10,000 songs until they learn "after C-E usually comes G" and can improvise.

---

## Step 1: MIDI → Numbers (Tokenization)

Computers need numbers. The **tokenizer** converts MIDI to a sequence of tokens.

### What's in a MIDI file?

```
MIDI = Instructions, not audio

  "At 0.0s: Play C4 (note 60), velocity 80"
  "At 0.5s: Stop C4"
  "At 0.5s: Play E4 (note 64), velocity 75"
  ...
```

### REMI Tokenization

Each musical event becomes tokens:

```
 Play middle-C, medium loud, quarter note, then wait
                        │
                        ▼

 ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌───────────┐
 │Pitch_60 │ │Vel_16   │ │Dur_qtr  │ │TimeShift  │ ...
 └─────────┘ └─────────┘ └─────────┘ └───────────┘
      │           │           │            │
      ▼           ▼           ▼            ▼
    "which     "how        "how         "wait
     note"     hard"       long"        time"
```

### Token Types (~3000 total vocabulary)

| Type | Examples | Meaning |
|------|----------|---------|
| Pitch | `Pitch_21` to `Pitch_109` | Which note (A0 to C8) |
| Velocity | `Vel_1` to `Vel_32` | How hard (32 levels) |
| Duration | `Dur_quarter`, `Dur_half` | Note length |
| TimeShift | `TimeShift_10ms`, etc. | Gap between events |
| Special | `BOS`, `EOS`, `PAD` | Start/End/Padding |
| Tags | `GENRE_JAZZ`, `MOOD_HAPPY` | Style conditioning |

### Example

```
Sheet music:  ♩C  ♩E  ♩G  (quarter notes)

Tokens: [BOS, Pitch_60, Vel_16, Dur_qtr, TimeShift, Pitch_64, Vel_16, ...]
              │
              └─ middle C
```

**Code:** [tokenizer.py](midi/tokenizer.py) - uses the `miditok` library with REMI encoding

---

## Step 2: The Neural Network (Transformer)

The model is a **Transformer** - same architecture as ChatGPT, but for music.

### Architecture Overview

```
    Input: [Pitch_60, Vel_16, Dur_qtr, TimeShift, Pitch_64, ...]
                                │
                                ▼
                    ┌───────────────────────┐
                    │   Token Embedding     │  Each token → 512-dim vector
                    └───────────┬───────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │ Positional Encoding   │  Add position info (1st, 2nd, 3rd...)
                    └───────────┬───────────┘
                                │
              ┌─────────────────┼─────────────────┐
              │                 │                 │
              ▼                 ▼                 ▼
         ┌─────────┐       ┌─────────┐       ┌─────────┐
         │ Block 1 │  ...  │ Block 6 │  ...  │Block 12 │   ← 12 identical blocks
         └─────────┘       └─────────┘       └─────────┘
              │                 │                 │
              └─────────────────┼─────────────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │     Output Head       │  → Probability for each token
                    └───────────────────────┘
                                │
                                ▼
            [0.01, 0.02, 0.15, ..., 0.30, ...]
                                      │
                                      └─ "Pitch_67 has 30% chance"
```

### What's Inside Each Block?

```
┌─────────────────────────────────────────────────────────┐
│                   TRANSFORMER BLOCK                      │
│                                                          │
│   Input                                                  │
│     │                                                    │
│     ▼                                                    │
│   ┌──────────────────────────────┐                      │
│   │  Multi-Head Self-Attention   │ ◄── "Look at all     │
│   │       (8 heads)              │      previous tokens" │
│   └──────────────┬───────────────┘                      │
│                  │                                       │
│                  ▼                                       │
│   ┌──────────────────────────────┐                      │
│   │     Feed-Forward Network     │ ◄── Process the      │
│   │    (512 → 2048 → 512)        │      information     │
│   └──────────────┬───────────────┘                      │
│                  │                                       │
│                  ▼                                       │
│               Output                                     │
└─────────────────────────────────────────────────────────┘
```

### What is Attention?

The model decides which previous tokens matter for predicting the next one:

```
    Predicting what comes after: [Pitch_60, Vel_16, Dur_qtr, TimeShift, Pitch_64, ???]


    Position:    1         2        3         4          5         6
    Token:    Pitch_60  Vel_16  Dur_qtr  TimeShift  Pitch_64    ???
                 │         │        │         │          │
    Attention:  25%       5%       5%       10%        35%      ◄── weights
                 │         │        │         │          │
                 └─────────┴────────┴─────────┴──────────┘
                                    │
                                    ▼
                           Weighted combination
                                    │
                                    ▼
                      Prediction: probably Pitch_67
                      (continuing C-E-G arpeggio)
```

**Multi-head** means 8 parallel attention patterns, each looking for different things:
- Head 1: melodic patterns
- Head 2: rhythmic patterns
- Head 3: harmonic relationships
- etc.

### Model Size

```
┌────────────────────────────────────┐
│  Embedding dimension:    512       │
│  Attention heads:        8         │
│  Transformer blocks:     12        │
│  Max sequence length:    8192      │
│  Vocabulary size:        ~3000     │
│  Total parameters:       ~85M      │
└────────────────────────────────────┘
```

**Code:** [model.py](midi/model.py)

---

## Step 3: Training

Training adjusts the model's ~85 million parameters until it predicts well.

### The Core Task: Next Token Prediction

```
    From a real song: [BOS, Pitch_60, Vel_16, Dur_qtr, TimeShift, Pitch_64, ...]


    Training examples:

    Input: [BOS]                              → Target: Pitch_60
    Input: [BOS, Pitch_60]                    → Target: Vel_16
    Input: [BOS, Pitch_60, Vel_16]            → Target: Dur_qtr
    Input: [BOS, Pitch_60, Vel_16, Dur_qtr]   → Target: TimeShift
    ...

    The model learns: "Given this context, what usually comes next?"
```

### Training Loop

```
    for epoch in 1..20:                          ◄── 20 passes through all data
        │
        │    for each batch of songs:            ◄── ~16 songs at a time per GPU
        │        │
        │        │   1. FORWARD: Feed tokens through model
        │        │              Get prediction for each position
        │        │
        │        │   2. LOSS: Compare predictions to actual next tokens
        │        │           Loss = how wrong (lower = better)
        │        │
        │        │   3. BACKWARD: Calculate how to fix each weight
        │        │
        │        │   4. UPDATE: Nudge all 85M parameters to reduce loss
        │        │
        │        └── repeat
        │
        │    Check validation set (are we learning or memorizing?)
        │    Save checkpoint if best so far
        │
        └── repeat
```

### Loss Function: Cross-Entropy

Measures how "surprised" the model is by the correct answer:

```
    Model predicts:  Pitch_60: 5%   Pitch_64: 20%   Pitch_67: 45%   ...
    Correct answer:  Pitch_67

    Loss = -log(0.45) = 0.35   (low = good, model was confident!)

    If model had said Pitch_67: 1%  →  Loss = 4.6  (high = bad!)
    If model had said Pitch_67: 99% →  Loss = 0.01 (nearly perfect!)
```

### Gradient Descent (How Learning Works)

```
    Loss
      │
    4 ├     /\
      │    /  \    /\
    3 ├   /    \  /  \
      │  /      \/    \
    2 ├ /              \   /\
      │/                \ /  \
    1 ├ ①→②→③→④          ⑤→⑥→★
      │                       ▲
      └───────────────────────┼─── Weight values
                              │
                           Optimal!

    Start random (①), follow gradient downhill, reach good spot (★)
```

**Code:** [train.py](midi/train.py)

---

## Step 4: Generation

Once trained, generate new music token by token.

### Autoregressive Generation

```
    Start:  [BOS]

    Step 1: Model([BOS]) → predicts Pitch_60 (25%)
            Sample → Pitch_60 ✓
            Sequence: [BOS, Pitch_60]

    Step 2: Model([BOS, Pitch_60]) → predicts Vel_16 (40%)
            Sample → Vel_16 ✓
            Sequence: [BOS, Pitch_60, Vel_16]

    Step 3: Model([BOS, Pitch_60, Vel_16]) → predicts Dur_qtr (50%)
            Sample → Dur_qtr ✓
            Sequence: [BOS, Pitch_60, Vel_16, Dur_qtr]

    ... repeat 512 times ...

    Final:  [BOS, Pitch_60, Vel_16, Dur_qtr, ...]
                            │
                            ▼
                       Decode to MIDI
                            │
                            ▼
                        New Song!
```

### Sampling Controls

Instead of always picking the top prediction, we sample with controls:

```
┌─────────────────────────────────────────────────────────────────┐
│ TEMPERATURE (default: 1.0)                                      │
│                                                                 │
│ Controls randomness. Lower = safer, Higher = more creative      │
│                                                                 │
│   Temp 0.5:                    Temp 1.5:                        │
│   Pitch_60: ████████ 50%       Pitch_60: ████ 22%               │
│   Pitch_64: █████ 30%          Pitch_64: ████ 20%               │
│   Pitch_67: ██ 15%             Pitch_67: ███ 18%                │
│   (differences amplified)      (differences flattened)          │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ TOP-K (default: 50)                                             │
│                                                                 │
│ Only consider the top 50 most likely tokens.                    │
│ Removes weird unlikely choices.                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ TOP-P / NUCLEUS (default: 0.95)                                 │
│                                                                 │
│ Keep tokens until cumulative probability reaches 95%.           │
│                                                                 │
│   Pitch_60: 30%  (cumulative: 30%) ✓                            │
│   Pitch_64: 25%  (cumulative: 55%) ✓                            │
│   Pitch_67: 20%  (cumulative: 75%) ✓                            │
│   Pitch_72: 10%  (cumulative: 85%) ✓                            │
│   Pitch_48: 5%   (cumulative: 90%) ✓                            │
│   Pitch_36: 4%   (cumulative: 94%) ✓                            │
│   Pitch_84: 2%   (cumulative: 96%) ✗ stop here                  │
└─────────────────────────────────────────────────────────────────┘
```

### Style Tags (Conditioning)

Guide generation with tags prepended to the prompt:

```
    Without tags: [BOS] → generic music

    With tags:    [GENRE_JAZZ, MOOD_HAPPY, TEMPO_FAST, BOS] → upbeat jazz


    How it works:

    During training, songs had tags prepended:
      Jazz song:     [GENRE_JAZZ, BOS, Pitch_60, ...]
      Classical:     [GENRE_CLASSICAL, BOS, Pitch_48, ...]

    Model learned: "After GENRE_JAZZ, I usually see swing rhythms, 7th chords..."

    At generation: Those tags prime the model's expectations!
```

**Code:** [generate.py](midi/generate.py)

---

## File Structure

```
├── train.py              ← CLI entry point for training
├── pretokenize.py        ← CLI entry point for pre-tokenization
├── generate.py           ← CLI entry point for generation
├── midi/                 ← Core package
│   ├── tokenizer.py      ← MIDI ↔ tokens conversion (REMI encoding)
│   ├── tags.py           ← Conditioning tag constants (genre, mood, etc.)
│   ├── tag_inference.py  ← Infer tags from MIDI content and metadata
│   ├── model.py          ← Neural network (single + multi-track Transformer)
│   ├── train.py          ← Training loop (single GPU, distributed, LoRA)
│   ├── generate.py       ← Generation (sampling, MP3 export)
│   ├── midi_io.py        ← MIDI read/write, humanize, multitrack conversion
│   └── multitrack_utils.py ← Track IDs, cross-track attention masks
├── configs/              ← Hardware-specific training configs
├── midi_files/           ← Put training MIDI files here
├── checkpoints/          ← Saved models
└── generated/            ← Generated MIDI files
```

---

## Quick Start

```bash
# 1. Add MIDI files to midi_files/

# 2. Pre-tokenize and train
python3 pretokenize.py
python3 train.py --config configs/a100_40gb.json    # Single GPU
torchrun --nproc_per_node=8 train.py --config configs/8x_a100.json  # Multi-GPU

# 3. Generate
python3 generate.py                              # Basic
python3 generate.py --tags "jazz happy fast"     # With style
python3 generate.py --prompt seed.mid            # Continue a song
python3 generate.py --creativity 0.8             # More conservative
python3 generate.py --mp3                        # Export audio
```

---

## Glossary

| Term | Meaning |
|------|---------|
| **Token** | Atomic unit (like a word, but for music) |
| **Embedding** | Converting token ID to a vector of numbers |
| **Attention** | Mechanism to look at relevant previous tokens |
| **Transformer** | Neural network architecture using attention |
| **Epoch** | One pass through all training data |
| **Loss** | How wrong the predictions are (lower = better) |
| **Gradient** | Direction to adjust weights to reduce loss |
| **Temperature** | Controls randomness in generation |
| **Autoregressive** | Generating one token at a time |
