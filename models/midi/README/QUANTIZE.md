# Quantization

Converts PyTorch checkpoints to quantized Core ML `.mlpackage` files for smaller model size on macOS.

## Usage

```bash
# Default float16 (~2x smaller)
python -m midi.quantize --checkpoint checkpoints/best_model.pt

# Int8 (~4x smaller)
python -m midi.quantize --checkpoint checkpoints/best_model.pt --quantization int8

# 4-bit palette (~8x smaller)
python -m midi.quantize --checkpoint checkpoints/best_model.pt --quantization palettize4

# 6-bit palette (~5x smaller)
python -m midi.quantize --checkpoint checkpoints/best_model.pt --quantization palettize6

# Custom output path
python -m midi.quantize --checkpoint checkpoints/best_model.pt --output models/small_model.mlpackage

# Merge LoRA adapter before quantizing
python -m midi.quantize --checkpoint checkpoints/best_model.pt --lora-adapter adapters/jazz.pt --quantization int8
```

## Quantization Modes

| Mode | Size Reduction | Quality | Notes |
|------|---------------|---------|-------|
| `float16` | ~2x | Best | Default. Minimal quality loss |
| `int8` | ~4x | Good | Linear symmetric quantization |
| `palettize6` | ~5x | Good | 6-bit k-means palette |
| `palettize4` | ~8x | Moderate | 4-bit k-means palette. Some quality loss |

## Options

| Flag | Description |
|------|-------------|
| `--checkpoint` | Path to model checkpoint (required) |
| `--quantization` | `float16`, `int8`, `palettize4`, `palettize6` (default: `float16`) |
| `--lora-adapter` | LoRA adapter to merge before quantizing |
| `--output` | Output `.mlpackage` path (default: auto from checkpoint name) |

## Output

The quantized model is saved as a `.mlpackage` directory next to the original checkpoint:

```
checkpoints/best_model.pt           # Original (~200 MB)
checkpoints/best_model_float16.mlpackage  # float16 (~100 MB)
checkpoints/best_model_int8.mlpackage     # int8 (~50 MB)
```

Both single-track and multitrack models are supported. The model type is auto-detected from the checkpoint.
