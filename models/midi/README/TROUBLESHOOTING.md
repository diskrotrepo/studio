# Troubleshooting

**"No MIDI files found"**
> Create `midi_files/` and add `.mid` files

**Out of memory (OOM)**
> Reduce `batch_size_per_gpu` or `seq_length` in your config JSON, or use `--batch-size` to override

**Generated music sounds random**
> Train longer, or lower creativity during generation (`--creativity 0.7`)

**Tokenization errors / crashes**
> Some MIDI files are corrupted and crash the symusic parser
> Run `python3 pretokenize.py --validate-only` to find bad files
> Then `./scripts/delete_bad_midi.sh` to remove them

**"Token cache not found" with multi-GPU**
> Run `python3 pretokenize.py` before distributed training

**NCCL errors with multi-GPU**
> Ensure all GPUs are visible: `nvidia-smi` should show all 8 GPUs
> Try setting `export NCCL_DEBUG=INFO` for detailed logs

**Slow multi-GPU training**
> Check GPU interconnect with `nvidia-smi topo -m`
> NVLink provides best performance; PCIe will be slower

**Tags don't seem to affect output**
> Tags require training data with style diversity; the model learns tag associations during training
> Try `--tags "list"` to see available tags

**Multi-track generation produces single track**
> Ensure you pre-tokenized in multi-track mode (the default). If you used `--single-track`, re-run without it
> The model needs to be trained on multi-track data to generate multiple tracks

**Tracks are not synchronized**
> Train longer - cross-track attention needs time to learn timing relationships
> Try using explicit track types: `--track-types "melody,bass,drums"`
