"""
MIDI pipeline diagnostic toolkit.

Validates tokenized data, training setup, and generation output to isolate
bugs across the tokenization -> training -> generation pipeline.

Usage:
    python3 -m midi.diagnose tokens --cache checkpoints/token_cache.pkl
    python3 -m midi.diagnose generation --checkpoint checkpoints/best_model.pt
    python3 -m midi.diagnose all --checkpoint-dir checkpoints/
"""

import argparse
import hashlib
import json
import sys
import tempfile
from collections import Counter
from pathlib import Path


def _percentile(sorted_data, p):
    """Compute percentile from pre-sorted data without numpy."""
    n = len(sorted_data)
    if n == 0:
        return 0
    idx = int(p / 100 * (n - 1))
    return sorted_data[idx]


def _get_special_token_id(vocab, *names):
    """Look up a special token ID by trying multiple name formats."""
    for name in names:
        if name in vocab:
            return vocab[name]
        suffixed = f"{name}_None"
        if suffixed in vocab:
            return vocab[suffixed]
    return None


def _extract_tokens(seq, is_multitrack):
    """Extract flat token list from a sequence (handles both formats)."""
    if is_multitrack and isinstance(seq, (tuple, list)) and len(seq) >= 1:
        tokens = seq[0]
        if hasattr(tokens, 'tolist'):
            return tokens.tolist()
        return list(tokens)
    if hasattr(seq, 'tolist'):
        return seq.tolist()
    return list(seq)


def diagnose_tokens(cache_path, tokenizer_path=None, json_output=None):
    """Validate pretokenized data in a cache file."""
    import pickle
    from .tokenizer import get_tokenizer, get_tag_tokens

    cache_path = Path(cache_path)
    if not cache_path.exists():
        print(f"ERROR: Cache file not found: {cache_path}")
        return False

    # Load cache
    print(f"Loading cache: {cache_path}")
    with open(cache_path, "rb") as f:
        data = pickle.load(f)

    if not isinstance(data, dict) or "sequences" not in data:
        print("ERROR: Invalid cache format (expected dict with 'sequences' key)")
        return False

    sequences = data["sequences"]
    is_multitrack = data.get("multitrack", False)
    print(f"Cache loaded: {len(sequences)} sequences, multitrack={is_multitrack}")

    # Load tokenizer
    tok_path = tokenizer_path or str(cache_path.parent / "tokenizer.json")
    print(f"Loading tokenizer: {tok_path}")
    tokenizer = get_tokenizer(tokenizer_path=tok_path)
    vocab_size = len(tokenizer.vocab)
    print(f"Vocab size: {vocab_size}")

    report = {"cache_path": str(cache_path), "num_sequences": len(sequences),
              "is_multitrack": is_multitrack, "vocab_size": vocab_size, "checks": {}}
    all_passed = True

    # ---- Check 1: Token ID bounds ----
    print("\n=== Check 1: Token ID Bounds ===")
    oob_count = 0
    oob_ids = set()
    total_tokens = 0
    for seq in sequences:
        tokens = _extract_tokens(seq, is_multitrack)
        total_tokens += len(tokens)
        for t in tokens:
            if t < 0 or t >= vocab_size:
                oob_count += 1
                oob_ids.add(t)

    report["total_tokens"] = total_tokens
    if oob_count == 0:
        print(f"  PASS: All {total_tokens:,} tokens within [0, {vocab_size})")
    else:
        print(f"  FAIL: {oob_count:,} out-of-bounds tokens found ({oob_count/total_tokens*100:.2f}%)")
        print(f"  OOB IDs (sample): {sorted(oob_ids)[:20]}")
        all_passed = False
    report["checks"]["token_bounds"] = {"passed": oob_count == 0, "oob_count": oob_count,
                                         "oob_ids_sample": sorted(oob_ids)[:20]}

    # ---- Check 2: Sequence length distribution ----
    print("\n=== Check 2: Sequence Length Distribution ===")
    lengths = []
    for seq in sequences:
        tokens = _extract_tokens(seq, is_multitrack)
        lengths.append(len(tokens))
    lengths.sort()

    if lengths:
        stats = {
            "min": lengths[0], "max": lengths[-1],
            "mean": round(sum(lengths) / len(lengths), 1),
            "median": lengths[len(lengths) // 2],
            "p5": _percentile(lengths, 5), "p25": _percentile(lengths, 25),
            "p75": _percentile(lengths, 75), "p95": _percentile(lengths, 95),
        }
        print(f"  Count: {len(lengths)}")
        print(f"  Min: {stats['min']}  Max: {stats['max']}  Mean: {stats['mean']}  Median: {stats['median']}")
        print(f"  P5: {stats['p5']}  P25: {stats['p25']}  P75: {stats['p75']}  P95: {stats['p95']}")

        # Warn on suspicious distributions
        if stats["min"] < 10:
            print(f"  WARNING: Very short sequences found (min={stats['min']})")
        if stats["max"] > 50000:
            print(f"  WARNING: Very long sequences found (max={stats['max']})")
        empty = sum(1 for l in lengths if l == 0)
        if empty:
            print(f"  WARNING: {empty} empty sequences (0 tokens)")
            all_passed = False
    else:
        stats = {}
        print("  No sequences found!")
        all_passed = False
    report["checks"]["sequence_lengths"] = stats

    # ---- Check 3: Tag token frequency ----
    print("\n=== Check 3: Tag Token Frequency ===")
    tag_tokens = get_tag_tokens(tokenizer)
    if not tag_tokens:
        print("  WARNING: No tag tokens found in tokenizer vocab")
    else:
        tag_id_set = set(tag_tokens.values())
        tag_id_to_name = {v: k for k, v in tag_tokens.items()}
        seqs_with_tags = 0
        tag_counter = Counter()

        for seq in sequences:
            tokens = _extract_tokens(seq, is_multitrack)
            seq_tags = [t for t in tokens if t in tag_id_set]
            if seq_tags:
                seqs_with_tags += 1
            for t in seq_tags:
                tag_counter[tag_id_to_name.get(t, f"id_{t}")] += 1

        pct = seqs_with_tags / len(sequences) * 100 if sequences else 0
        print(f"  Sequences with tags: {seqs_with_tags}/{len(sequences)} ({pct:.1f}%)")

        if tag_counter:
            # Group by category
            categories = Counter()
            for tag_name, count in tag_counter.items():
                prefix = tag_name.split("_")[0] if "_" in tag_name else tag_name
                categories[prefix] += count

            print(f"  Tag categories: {dict(categories.most_common(10))}")
            print(f"  Top 15 tags: {dict(tag_counter.most_common(15))}")
        else:
            print("  WARNING: No tag tokens found in any sequence")

        if pct < 50 and sequences:
            print(f"  WARNING: Less than 50% of sequences have conditioning tags")
            all_passed = False

    report["checks"]["tag_frequency"] = {
        "sequences_with_tags": seqs_with_tags if tag_tokens else 0,
        "tag_distribution": dict(tag_counter.most_common(30)) if tag_tokens else {},
    }

    # ---- Check 4: Special token markers ----
    print("\n=== Check 4: Special Token Markers ===")
    vocab = tokenizer.vocab
    bos_id = _get_special_token_id(vocab, "BOS")
    eos_id = _get_special_token_id(vocab, "EOS")
    pad_id = _get_special_token_id(vocab, "PAD")
    track_start_id = _get_special_token_id(vocab, "TRACK_START")
    track_end_id = _get_special_token_id(vocab, "TRACK_END")
    bar_start_id = _get_special_token_id(vocab, "BAR_START")

    print(f"  Token IDs: BOS={bos_id}, EOS={eos_id}, PAD={pad_id}, "
          f"TRACK_START={track_start_id}, TRACK_END={track_end_id}, BAR_START={bar_start_id}")

    bos_present = 0
    eos_present = 0
    unbalanced_tracks = 0
    sample_size = min(len(sequences), 500)  # Check a sample for large datasets

    for seq in sequences[:sample_size]:
        tokens = _extract_tokens(seq, is_multitrack)
        if not tokens:
            continue

        # BOS check: should be within first few tokens (after tags)
        if bos_id is not None and bos_id in tokens[:50]:
            bos_present += 1

        # EOS check: should be at or near end
        if eos_id is not None and eos_id in tokens[-5:]:
            eos_present += 1

        # Track marker balance (multitrack only)
        if is_multitrack and track_start_id is not None and track_end_id is not None:
            starts = tokens.count(track_start_id)
            ends = tokens.count(track_end_id)
            if starts != ends:
                unbalanced_tracks += 1

    print(f"  Checked {sample_size} sequences:")
    print(f"  BOS present: {bos_present}/{sample_size} ({bos_present/sample_size*100:.0f}%)")
    print(f"  EOS present: {eos_present}/{sample_size} ({eos_present/sample_size*100:.0f}%)")
    if is_multitrack:
        print(f"  Unbalanced TRACK_START/END: {unbalanced_tracks}/{sample_size}")
        if unbalanced_tracks > 0:
            print(f"  WARNING: {unbalanced_tracks} sequences have mismatched track markers")
            all_passed = False

    report["checks"]["special_tokens"] = {
        "bos_present_pct": round(bos_present / sample_size * 100, 1) if sample_size else 0,
        "eos_present_pct": round(eos_present / sample_size * 100, 1) if sample_size else 0,
        "unbalanced_tracks": unbalanced_tracks,
    }

    # ---- Check 5: Duplicate sequences ----
    print("\n=== Check 5: Duplicate Sequences ===")
    hashes = []
    for seq in sequences:
        tokens = _extract_tokens(seq, is_multitrack)
        h = hashlib.md5(str(tokens).encode()).hexdigest()
        hashes.append(h)

    unique = len(set(hashes))
    dupes = len(hashes) - unique
    dupe_pct = dupes / len(hashes) * 100 if hashes else 0
    print(f"  Total: {len(hashes)}, Unique: {unique}, Duplicates: {dupes} ({dupe_pct:.1f}%)")
    if dupe_pct > 10:
        print(f"  WARNING: High duplicate rate ({dupe_pct:.0f}%) may waste training capacity")
    report["checks"]["duplicates"] = {"total": len(hashes), "unique": unique,
                                       "duplicate_count": dupes, "duplicate_pct": round(dupe_pct, 1)}

    # ---- Summary ----
    print(f"\n{'='*50}")
    print(f"RESULT: {'ALL CHECKS PASSED' if all_passed else 'ISSUES FOUND'}")
    print(f"{'='*50}")

    if json_output:
        report["all_passed"] = all_passed
        with open(json_output, "w") as f:
            json.dump(report, f, indent=2)
        print(f"Report saved to: {json_output}")

    return all_passed


def diagnose_generation(checkpoint_path, tokenizer_path=None, num_samples=3, seed=42):
    """Validate the generation pipeline by producing and checking sample outputs."""
    import torch

    checkpoint_path = Path(checkpoint_path)
    if not checkpoint_path.exists():
        print(f"ERROR: Checkpoint not found: {checkpoint_path}")
        return False

    # Load tokenizer
    tok_path = tokenizer_path or str(checkpoint_path.parent / "tokenizer.json")
    from .tokenizer import get_tokenizer, get_tag_tokens
    print(f"Loading tokenizer: {tok_path}")
    tokenizer = get_tokenizer(tokenizer_path=tok_path)
    vocab_size = len(tokenizer.vocab)
    print(f"Vocab size: {vocab_size}")

    # Load checkpoint and check vocab consistency
    print(f"Loading checkpoint: {checkpoint_path}")
    checkpoint = torch.load(checkpoint_path, map_location="cpu", weights_only=False)
    ckpt_vocab = checkpoint.get("vocab_size")
    if ckpt_vocab is not None:
        if ckpt_vocab != vocab_size:
            print(f"  FAIL: Vocab mismatch! Checkpoint expects {ckpt_vocab}, tokenizer has {vocab_size}")
            print(f"  This will cause embedding index errors. Retokenize with the same tag set.")
            return False
        else:
            print(f"  PASS: Vocab sizes match ({vocab_size})")
    else:
        print(f"  WARNING: Checkpoint does not store vocab_size (old format)")

    # Determine model type
    ckpt_config = checkpoint.get("config", {})
    is_multitrack = ckpt_config.get("max_tracks") is not None
    print(f"Model type: {'multitrack' if is_multitrack else 'single-track'}")
    print(f"Model config: d_model={ckpt_config.get('d_model')}, n_layers={ckpt_config.get('n_layers')}, "
          f"n_heads={ckpt_config.get('n_heads')}")
    print(f"Trained for {checkpoint.get('epoch', '?')} epochs, loss={checkpoint.get('loss', '?')}")

    # Build model
    device = torch.device("cpu")
    if torch.cuda.is_available():
        device = torch.device("cuda")
    elif hasattr(torch.backends, "mps") and torch.backends.mps.is_available():
        device = torch.device("mps")
    print(f"Using device: {device}")

    if is_multitrack:
        from .model import MultiTrackMusicTransformer
        model = MultiTrackMusicTransformer(
            vocab_size=vocab_size,
            d_model=ckpt_config["d_model"],
            n_heads=ckpt_config["n_heads"],
            n_layers=ckpt_config["n_layers"],
            max_seq_len=ckpt_config.get("max_seq_len", 2048),
            max_tracks=ckpt_config.get("max_tracks", 16),
        )
    else:
        from .model import MusicTransformer
        model = MusicTransformer(
            vocab_size=vocab_size,
            d_model=ckpt_config["d_model"],
            n_heads=ckpt_config["n_heads"],
            n_layers=ckpt_config["n_layers"],
            max_seq_len=ckpt_config.get("max_seq_len", 2048),
        )

    # Load weights
    state_dict = checkpoint["model_state_dict"]
    if any(k.startswith("_orig_mod.") for k in state_dict.keys()):
        state_dict = {k.replace("_orig_mod.", ""): v for k, v in state_dict.items()}
    model.load_state_dict(state_dict)
    model = model.to(device)
    model.eval()
    print("Model loaded successfully")

    # Get special token IDs
    vocab = tokenizer.vocab
    bos_id = _get_special_token_id(vocab, "BOS")
    eos_id = _get_special_token_id(vocab, "EOS")
    track_start_id = _get_special_token_id(vocab, "TRACK_START")
    track_end_id = _get_special_token_id(vocab, "TRACK_END")

    # Generate samples
    successes = 0
    print(f"\n=== Generating {num_samples} samples ===")

    for i in range(num_samples):
        print(f"\n--- Sample {i+1}/{num_samples} (seed={seed+i}) ---")
        torch.manual_seed(seed + i)

        try:
            # Build a minimal prompt
            prompt = []
            if bos_id is not None:
                prompt.append(bos_id)

            if is_multitrack and track_start_id is not None:
                prompt.append(track_start_id)

            prompt_tensor = torch.tensor([prompt], dtype=torch.long, device=device)

            with torch.no_grad():
                output = model.generate(
                    prompt_tensor,
                    max_new_tokens=200,
                    temperature=0.85,
                    top_k=50,
                    vocab_size=vocab_size,
                    vocab=vocab,
                )

            tokens = output[0].tolist()
            print(f"  Generated {len(tokens)} tokens")

            # Check token bounds
            oob = [t for t in tokens if t < 0 or t >= vocab_size]
            if oob:
                print(f"  FAIL: {len(oob)} out-of-bounds tokens: {oob[:10]}")
            else:
                print(f"  PASS: All tokens in valid range")

            # Token distribution
            unique_tokens = len(set(tokens))
            token_counts = Counter(tokens)
            print(f"  Unique tokens: {unique_tokens}, most common: {token_counts.most_common(5)}")

            # Check for degenerate output (all same token = collapsed model)
            if unique_tokens <= 3:
                print(f"  WARNING: Only {unique_tokens} unique tokens - model may have collapsed")

            # Check marker balance (multitrack)
            if is_multitrack and track_start_id is not None and track_end_id is not None:
                starts = tokens.count(track_start_id)
                ends = tokens.count(track_end_id)
                if starts != ends:
                    print(f"  WARNING: Marker imbalance: {starts} TRACK_START vs {ends} TRACK_END")
                else:
                    print(f"  Marker balance: {starts} tracks")

            # Try MIDI decode
            try:
                with tempfile.NamedTemporaryFile(suffix=".mid", delete=True) as tmp:
                    # Strip BOS/EOS for decode
                    decode_tokens = tokens
                    if bos_id is not None and decode_tokens and decode_tokens[0] == bos_id:
                        decode_tokens = decode_tokens[1:]
                    if eos_id is not None and eos_id in decode_tokens:
                        decode_tokens = decode_tokens[:decode_tokens.index(eos_id)]

                    if is_multitrack:
                        from .tokenization.midi_io import tokens_to_multitrack_midi
                        tokens_to_multitrack_midi(tokenizer, decode_tokens, tmp.name)
                    else:
                        from .tokenization.midi_io import tokens_to_midi
                        tokens_to_midi(tokenizer, decode_tokens, tmp.name)
                    print(f"  PASS: MIDI decode succeeded")
                    successes += 1
            except Exception as e:
                print(f"  FAIL: MIDI decode error: {e}")

        except Exception as e:
            print(f"  FAIL: Generation error: {e}")

    print(f"\n{'='*50}")
    print(f"RESULT: {successes}/{num_samples} samples generated and decoded successfully")
    print(f"{'='*50}")

    return successes == num_samples


def diagnose_all(checkpoint_dir, seed=42):
    """Run all diagnostics as an end-to-end smoke test."""
    checkpoint_dir = Path(checkpoint_dir)
    results = {}

    # Find cache and checkpoint files
    cache_path = checkpoint_dir / "token_cache.pkl"
    tokenizer_path = checkpoint_dir / "tokenizer.json"
    checkpoint_path = checkpoint_dir / "best_model.pt"

    tok_path = str(tokenizer_path) if tokenizer_path.exists() else None

    print("=" * 60)
    print("MIDI Pipeline Diagnostics - Full Check")
    print("=" * 60)

    # Step 1: Token validation
    if cache_path.exists():
        print("\n\n>>> STAGE 1: Token Cache Validation\n")
        results["tokens"] = diagnose_tokens(cache_path, tok_path)
    else:
        print(f"\nSKIP: Token cache not found at {cache_path}")
        results["tokens"] = None

    # Step 2: Generation validation
    if checkpoint_path.exists():
        print("\n\n>>> STAGE 2: Generation Pipeline Validation\n")
        results["generation"] = diagnose_generation(checkpoint_path, tok_path,
                                                     num_samples=1, seed=seed)
    else:
        print(f"\nSKIP: Checkpoint not found at {checkpoint_path}")
        results["generation"] = None

    # Summary
    print("\n\n" + "=" * 60)
    print("OVERALL SUMMARY")
    print("=" * 60)
    for stage, passed in results.items():
        if passed is None:
            status = "SKIPPED"
        elif passed:
            status = "PASSED"
        else:
            status = "FAILED"
        print(f"  {stage}: {status}")

    all_passed = all(v is not False for v in results.values())
    print(f"\nOverall: {'PASSED' if all_passed else 'ISSUES FOUND'}")
    return all_passed


def main():
    parser = argparse.ArgumentParser(
        description="MIDI pipeline diagnostic toolkit",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 -m midi.diagnose tokens --cache checkpoints/token_cache.pkl
  python3 -m midi.diagnose generation --checkpoint checkpoints/best_model.pt --samples 3
  python3 -m midi.diagnose all --checkpoint-dir checkpoints/
        """,
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    # tokens subcommand
    tokens_parser = subparsers.add_parser("tokens", help="Validate pretokenized data")
    tokens_parser.add_argument("--cache", default="checkpoints/token_cache.pkl",
                               help="Path to token cache file")
    tokens_parser.add_argument("--tokenizer", default=None,
                               help="Path to tokenizer.json (default: same dir as cache)")
    tokens_parser.add_argument("--json", default=None,
                               help="Output JSON report to this path")

    # generation subcommand
    gen_parser = subparsers.add_parser("generation", help="Validate generation pipeline")
    gen_parser.add_argument("--checkpoint", default="checkpoints/best_model.pt",
                            help="Path to model checkpoint")
    gen_parser.add_argument("--tokenizer", default=None,
                            help="Path to tokenizer.json")
    gen_parser.add_argument("--samples", type=int, default=3,
                            help="Number of samples to generate")
    gen_parser.add_argument("--seed", type=int, default=42,
                            help="Random seed for reproducibility")

    # all subcommand
    all_parser = subparsers.add_parser("all", help="Run all diagnostics")
    all_parser.add_argument("--checkpoint-dir", default="checkpoints",
                            help="Path to checkpoint directory")
    all_parser.add_argument("--seed", type=int, default=42,
                            help="Random seed for generation")

    args = parser.parse_args()

    if args.command == "tokens":
        ok = diagnose_tokens(args.cache, args.tokenizer, args.json)
    elif args.command == "generation":
        ok = diagnose_generation(args.checkpoint, args.tokenizer, args.samples, args.seed)
    elif args.command == "all":
        ok = diagnose_all(args.checkpoint_dir, args.seed)
    else:
        parser.print_help()
        sys.exit(1)

    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
