# Debug Pipeline

Validate the full tokenize → train → generate pipeline in stages.

All commands use the top-level wrapper scripts (`pretokenize.py`, `train.py`, `generate.py`).
Add `--debug` to any train/generate command for verbose model-level logging (shapes, sampling stats, cache events).

## Stage 1 — Overfit on 10 files

Prove the model can learn. If it can't memorize 10 files, something is broken.

### Pick ~10 MIDI files

```bash
mkdir -p midi_debug
find midi_files -maxdepth 1 -name '*.mid' | head -10 | xargs -I{} cp {} midi_debug/
```

### Pretokenize

```bash
python3 pretokenize.py \
  --midi-dir midi_debug \
  --output checkpoints/debug/token_cache.pkl \
  2>&1 | tee logs/pretokenize_debug.log
```

Check: no errors, all 10 files tokenized.

### Train (overfit)

```bash
python3 train.py \
  --midi-dir midi_debug \
  --checkpoint-dir checkpoints/debug \
  --config configs/debug_overfit.json \
  --batch-size 2 --grad-accum 1 --max-files 10 \
  --debug \
  2>&1 | tee logs/train_debug.log
```

All hyperparameters are in `configs/debug_overfit.json` — do NOT pass `--lr` or `--epochs` on the CLI (they override the config).

Expected: loss drops steadily toward near-zero (< 0.5) by epoch 200.

### Generate

```bash
python3 generate.py \
  --checkpoint checkpoints/debug/best_model.pt \
  --duration 30 \
  --seed 42 \
  --creativity 0.5 \
  --mp3 \
  --debug \
  2>&1 | tee logs/generate_debug.log
```

Low creativity (temperature) + seed = reproducible output. Since the model
memorized only 10 files, output should sound like a copy of those files.
If it's random noise, something is wrong in generation.

### Pass criteria

- Train loss < 0.5
- Generated MIDI has audible musical content (not silence, not noise)

---

## Stage 2 — Generalization on 500 files

Prove the model can generalize to unseen data.

### Pick 500 MIDI files

```bash
mkdir -p midi_500
find midi_files -maxdepth 1 -name '*.mid' | shuf -n 500 | xargs -I{} cp {} midi_500/
```

(macOS: use `gshuf` from `brew install coreutils`)

### Pretokenize

```bash
python3 pretokenize.py \
  --midi-dir midi_500 \
  --output checkpoints/500/token_cache.pkl \
  2>&1 | tee logs/pretokenize_500.log
```

### Train

```bash
python3 train.py \
  --midi-dir midi_500 \
  --checkpoint-dir checkpoints/500 \
  --debug \
  2>&1 | tee logs/train_500.log
```

Uses default config: `val_split=0.1`, `dropout=0.1`, `epochs=20`, `early_stopping_patience=5`, `lr=3e-4`. No `--config` needed.

### Generate

```bash
python3 generate.py \
  --checkpoint checkpoints/500/best_model.pt \
  --duration 30 \
  --seed 42 \
  --creativity 0.8 \
  --debug \
  2>&1 | tee logs/generate_500.log
```

### Pass criteria

- Val loss decreases over training (model is learning, not just memorizing)
- Early stopping triggers (val loss plateaus = model extracted what it can)
- Generated MIDI sounds like music, not a copy of a specific training file

---

## Stage 3 — 5k files on A100

Prove the model can learn real diversity before scaling to full dataset.

### Pick 5000 MIDI files

```bash
mkdir -p midi_5k
find midi_files -maxdepth 1 -name '*.mid' | shuf -n 5000 | xargs -I{} cp {} midi_5k/
```

(macOS: use `gshuf` from `brew install coreutils`)

### Pretokenize

```bash
python3 pretokenize.py \
  --midi-dir midi_5k \
  --output checkpoints/5k/token_cache.pkl \
  2>&1 | tee logs/pretokenize_5k.log
```

### Train

```bash
python3 train.py \
  --midi-dir midi_5k \
  --checkpoint-dir checkpoints/5k \
  --config configs/a100_40gb_5k.json \
  --debug \
  2>&1 | tee logs/train_5k.log
```

All hyperparameters are in `configs/a100_40gb_5k.json` — do NOT pass `--lr` or `--epochs` on the CLI (they override the config).

### Generate

```bash
python3 generate.py \
  --checkpoint checkpoints/5k/best_model.pt \
  --duration 30 \
  --seed 42 \
  --creativity 0.8 \
  --mp3 \
  --debug \
  2>&1 | tee logs/generate_5k.log
```

If output sounds boring/repetitive, try higher creativity and repetition penalty:

```bash
python3 generate.py \
  --checkpoint checkpoints/5k/best_model.pt \
  --duration 60 \
  --creativity 1.1 \
  --repetition-penalty 1.2 \
  --mp3 \
  --debug \
  2>&1 | tee logs/generate_5k_creative.log
```

### Pass criteria

- Val loss decreases consistently over training
- Val loss < train loss from Stage 2 (model benefits from more data)
- Early stopping triggers around epoch 20-30
- Generated MIDI has variety — not stuck in loops, different from training files

---

## Stage 4 — Full dataset

Scale up once Stage 3 passes.

```bash
python3 pretokenize.py \
  --midi-dir midi_files \
  --output checkpoints/full/token_cache.pkl \
  2>&1 | tee logs/pretokenize_full.log

python3 train.py \
  --midi-dir midi_files \
  --checkpoint-dir checkpoints/full \
  --debug \
  2>&1 | tee logs/train_full.log
```

If val loss plateaus and generated output is still poor, the 42M model is saturated — scale up `d_model`/`n_layers`.

---

## Debug logging

Add `--debug` to `generate.py` or `train.py` to enable DEBUG-level logging. This logs:

**Generation (model-level):**
- Prompt shape, device, dtype, and generation parameters
- KV cache prefill/invalidation events with sequence lengths
- Sliding window truncation (when sequence exceeds max_seq_len)
- Per-token sampling stats every 50 tokens: top-5 probabilities, entropy, chosen token
- Final generation summary: tokens generated, tokens/sec

**Training:**
- Full model config and parameter counts at startup
- Per-batch input shapes and token ranges (already logged at epoch 1 batch 0)
- Gradient norm statistics per epoch

**Sampling (`_apply_sampling_filters`):**
- Pre/post-filter probability distribution stats (entropy, top-1 prob, effective vocab size)
- Repetition penalty effects

Logs go to both console and `logs/` directory. Pipe through `grep DEBUG` to isolate model diagnostics.

---

## Symptom → likely problem

| Symptom | Likely problem |
|---|---|
| Loss doesn't go down at all | Learning rate too low, data not loading, model bug |
| Loss goes to NaN | LR too high, numerical instability |
| Loss plateaus at ~4-6 | Model not seeing the data correctly, tokenization issue |
| Loss reaches ~0 but generation is garbage | Decoding/detokenization bug in generate.py |
| Loss diverges after initial progress | LR too high (OneCycleLR peak too aggressive) |
| Pretokenize produces 0 sequences | Validation rejecting all files, path issue |
| Generation repeats same token pattern | Repetition penalty too low, or model overfit on few files |
| Generation sounds random despite low loss | Temperature too high, or prompt tokens misaligned with training vocab |
| KV cache invalidation every step | max_seq_len too small for the generation length |

## Common gotchas

- **Don't override config with CLI args.** `--lr` and `--epochs` override config file values. If you're using a config, let it drive.
- **Pretokenize before training.** The train script expects `token_cache.pkl` inside `--checkpoint-dir`.
- **Delete old checkpoints before retraining.** Stale checkpoints cause scheduler state mismatches.
- **Use `python3`** not `python` — python3 resolves to 3.12 with pytest on this system.
- **Use `find` not `ls`** for large directories (100k+ files). `ls *.mid` will hit argument list limits.
- **Check tokenizer match.** The saved `tokenizer.json` in the checkpoint dir must match the one used during training. Vocab mismatch causes silent garbage output.
