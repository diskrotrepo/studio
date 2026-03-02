# Diagnostic Guide

Diagnostic steps to run at each stage of model development, ordered by pipeline stage.

---

## Stage 1: Tokenization

Run these after pretokenization, before training.

### Validate raw MIDI files

Runs automatically during `pretokenize.py` unless `--skip-validation` is passed. Catches corrupted files, empty files, and files that hang during parsing.

```bash
# Check the pretokenize output for failures
python3 pretokenize.py \
  --midi-dir midi_files \
  --output checkpoints/token_cache.pkl \
  2>&1 | tee logs/pretokenize.log
```

**What to look for:**
- `bad_midi_files.txt` — list of rejected files and reasons
- Failure rate > 20% — suggests systemic data quality issue (wrong file format, corrupted batch)
- 0 sequences produced — path issue or all files invalid

### Diagnose token cache

Validates the tokenized data is structurally sound.

```bash
python3 -m midi.diagnose tokens --cache checkpoints/token_cache.pkl
```

**Checks and what they mean:**

| Check | Pass criteria | On failure |
|-------|--------------|------------|
| Token ID bounds | All tokens in `[0, vocab_size)` | Retokenize — vocab mismatch between tokenizer and data |
| Sequence length distribution | No empty sequences, reasonable min/max | Filter or retokenize problematic files |
| Tag token frequency | >50% of sequences have conditioning tags | Tags may not be injected — check `--tags` flag during pretokenize |
| Special token markers | BOS/EOS present, TRACK_START/END balanced | Tokenizer config missing special tokens |
| Duplicate sequences | <10% duplicates | Deduplicate source MIDI files |

**Save a JSON report for CI:**

```bash
python3 -m midi.diagnose tokens \
  --cache checkpoints/token_cache.pkl \
  --json checkpoints/token_report.json
```

---

## Stage 2: Training

### Automatic validation gate

The training script runs a data validation gate automatically before training starts. It checks for issues that would cause silent model failures.

**Fatal issues (blocks training):**
- Missing `TRACK_START`/`TRACK_END`/`BAR_START` in vocabulary (multitrack) — without these, `compute_track_ids` silently returns all `-1`s and cross-track attention is completely broken
- Out-of-bounds token IDs — crashes `nn.Embedding`
- All sequences empty — nothing to train on
- Track IDs outside `[-1, max_tracks-1]` — crashes `TrackEmbedding`
- >20% of sequences with unbalanced track markers

**Warnings (logged but training proceeds):**
- Missing `BOS`/`EOS` tokens
- >10% of sequences shorter than 10 tokens
- >50% of sequences exceeding `max_seq_len` (undefined positional encoding behavior)
- Token ID 0 is not a PAD token (padding injects meaningful tokens)
- Non-monotonic bar positions within tracks (incorrect cross-track attention)
- Degenerate token distribution (>90% one token or <20 unique tokens)

### Runtime monitoring

The training loop catches issues as they happen:

**Non-finite loss detection:**
If loss becomes NaN or Inf, training stops immediately with diagnostic output showing token ranges, gradient norms, and logit ranges. Common causes:
- Learning rate too high
- OOB tokens in data (should be caught by validation gate)
- Numerical instability (reduce LR or enable gradient clipping)

**Anomalous gradient norms:**
If gradient norm exceeds 10x the running average, the optimizer step is skipped and a warning is logged. Frequent skips suggest:
- Bad data batches
- Learning rate too high
- Model instability

**First-batch token distribution:**
On epoch 1 batch 0, the training loop logs the unique token count, min/max range, and top 20 most common tokens. Check this matches expectations.

### What to watch in training logs

```bash
# Monitor training
tail -f logs/train.log

# Key things to look for:
# 1. Validation gate output (should say "PASSED" or show warnings)
# 2. Loss decreasing over epochs
# 3. No "skipped step" warnings (gradient anomalies)
# 4. Val loss tracking train loss (not diverging)
```

### Debug mode

Add `--debug` to `train.py` for verbose logging:
- Full model config and parameter counts at startup
- Per-batch input shapes and token ranges
- Gradient norm statistics per epoch

```bash
python3 train.py \
  --midi-dir midi_files \
  --checkpoint-dir checkpoints \
  --debug \
  2>&1 | tee logs/train_debug.log
```

---

## Stage 3: Generation

Run these after training to validate the full pipeline end-to-end.

### Diagnose generation pipeline

```bash
python3 -m midi.diagnose generation \
  --checkpoint checkpoints/best_model.pt \
  --samples 5
```

**Checks and what they mean:**

| Check | Pass criteria | On failure |
|-------|--------------|------------|
| Vocab size match | Checkpoint vocab == tokenizer vocab | Retokenize with matching tokenizer, or retrain |
| Model loads | No errors loading weights | Corrupted checkpoint or architecture mismatch |
| Token bounds | Generated tokens in `[0, vocab_size)` | Model bug in output projection |
| Token diversity | >3 unique tokens per sample | Model collapsed — overfit, bad data, or too few epochs |
| MIDI decode | Tokens decode to valid MIDI | Detokenization bug or garbage output |
| Track marker balance | Equal TRACK_START/TRACK_END (multitrack) | Model not learning track structure |

### Full pipeline smoke test

Runs both token validation and generation validation:

```bash
python3 -m midi.diagnose all --checkpoint-dir checkpoints/
```

### Manual generation check

```bash
# Low creativity for reproducible sanity check
python3 generate.py \
  --checkpoint checkpoints/best_model.pt \
  --duration 30 \
  --seed 42 \
  --creativity 0.5 \
  --mp3 \
  --debug

# Higher creativity for quality assessment
python3 generate.py \
  --checkpoint checkpoints/best_model.pt \
  --duration 60 \
  --creativity 1.0 \
  --repetition-penalty 1.2 \
  --mp3
```

**What to listen for:**
- Audible musical content (not silence or noise)
- Structural coherence (phrases, repetition, variation)
- Not a direct copy of training data (for larger datasets)
- Multitrack: instruments playing together, not identical parts

---

## Quick Reference

### Symptom to diagnostic

| Symptom | Run this | Likely problem |
|---------|----------|---------------|
| Training crashes immediately | Check validation gate output | OOB tokens, missing special tokens |
| Loss stays flat | `diagnose tokens` | Data not loading correctly, tokenization issue |
| Loss goes to NaN | Check `--debug` output | LR too high, numerical instability |
| Loss plateaus at 4-6 | `diagnose tokens` + check tag coverage | Model not seeing data correctly |
| Good loss but garbage generation | `diagnose generation` | Vocab mismatch, detokenization bug |
| Generation repeats same pattern | Generate with `--debug` | Repetition penalty too low, or overfit |
| Multitrack sounds like single track | `diagnose tokens` (check track markers) | Missing TRACK_START/END/BAR_START in vocab |
| Silent MIDI output | `diagnose generation` | Model collapsed or token distribution degenerate |

### Diagnostic commands at a glance

```bash
# After pretokenization
python3 -m midi.diagnose tokens --cache checkpoints/token_cache.pkl

# After training
python3 -m midi.diagnose generation --checkpoint checkpoints/best_model.pt

# Full pipeline
python3 -m midi.diagnose all --checkpoint-dir checkpoints/

# With JSON report
python3 -m midi.diagnose tokens --cache checkpoints/token_cache.pkl --json report.json
```
