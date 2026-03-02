"""
Diagnose training data and generation quality issues.

Usage:
    python -m midi.diagnose
    python -m midi.diagnose --cache checkpoints/token_cache.pkl
    python -m midi.diagnose --tokenizer checkpoints/tokenizer.json
"""

import pickle
import argparse
import os
from pathlib import Path
from collections import Counter

_ROOT = Path(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def load_cache(cache_path):
    with open(cache_path, "rb") as f:
        data = pickle.load(f)
    return data


def check_bar_resets(token_ids, id_to_token):
    """Check if bar numbers go backwards (sign of naive track concatenation)."""
    resets = []
    prev_bar = -1
    for i, tid in enumerate(token_ids):
        name = id_to_token.get(tid, "")
        if name.startswith("Bar_"):
            try:
                bar_num = int(name.split("_")[1])
            except (ValueError, IndexError):
                continue
            if bar_num < prev_bar:
                resets.append((i, prev_bar, bar_num))
            prev_bar = bar_num
    return resets


def check_token_ordering(token_ids, id_to_token):
    """Check if REMI token ordering is correct (Pitch -> Velocity -> Duration)."""
    violations = 0
    total_pitch = 0
    for i, tid in enumerate(token_ids):
        name = id_to_token.get(tid, "")
        if name.startswith("Pitch_"):
            total_pitch += 1
            if i + 1 < len(token_ids):
                next_name = id_to_token.get(token_ids[i + 1], "")
                if not next_name.startswith("Velocity_"):
                    violations += 1
    return violations, total_pitch


def analyze_sequence(token_ids, id_to_token):
    """Analyze a single token sequence."""
    token_types = Counter()
    for tid in token_ids:
        name = id_to_token.get(tid, f"UNK_{tid}")
        # Extract type prefix
        prefix = name.split("_")[0] if "_" in name else name
        token_types[prefix] += 1
    return token_types


def main():
    parser = argparse.ArgumentParser(description="Diagnose MIDI training data")
    parser.add_argument("--cache", default=str(_ROOT / "checkpoints/token_cache.pkl"))
    parser.add_argument("--tokenizer", default=str(_ROOT / "checkpoints/tokenizer.json"))
    parser.add_argument("--num-sequences", type=int, default=None,
                        help="Number of sequences to analyze (default: all)")
    args = parser.parse_args()

    cache_path = Path(args.cache)
    tokenizer_path = Path(args.tokenizer)

    # Load tokenizer
    if not tokenizer_path.exists():
        print(f"ERROR: Tokenizer not found at {tokenizer_path}")
        return 1

    from miditok import REMI
    tokenizer = REMI(params=tokenizer_path)
    id_to_token = {v: k for k, v in tokenizer.vocab.items()}
    vocab_size = len(tokenizer.vocab)
    print(f"Tokenizer vocab size: {vocab_size}")

    # Count special token types
    special_count = 0
    tag_count = 0
    music_count = 0
    for name in tokenizer.vocab:
        if any(name.startswith(p) for p in ["GENRE_", "MOOD_", "TEMPO_", "KEY_", "TIMESIG_",
                "DENSITY_", "DYNAMICS_", "LENGTH_", "REGISTER_", "ARRANGEMENT_",
                "RHYTHM_", "HARMONY_", "ARTICULATION_", "EXPRESSION_", "ERA_", "ARTIST_"]):
            tag_count += 1
        elif any(name.startswith(p) for p in ["PAD_", "BOS_", "EOS_", "TRACK", "BAR_START"]):
            special_count += 1
        else:
            music_count += 1
    print(f"  Music tokens: {music_count}")
    print(f"  Tag tokens: {tag_count}")
    print(f"  Special tokens: {special_count}")

    # Check BOS/EOS token names
    print(f"\n--- Token Name Check ---")
    for name in ["BOS", "BOS_None", "EOS", "EOS_None", "PAD", "PAD_None"]:
        tid = tokenizer.vocab.get(name)
        print(f"  {name}: {'ID ' + str(tid) if tid is not None else 'NOT FOUND'}")

    # Check one_token_stream behavior
    print(f"\n--- Tokenizer Config ---")
    if hasattr(tokenizer, 'config'):
        config = tokenizer.config
        if hasattr(config, 'one_token_stream_for_programs'):
            print(f"  one_token_stream_for_programs: {config.one_token_stream_for_programs}")
        else:
            print(f"  one_token_stream_for_programs: NOT SET (check miditok version)")
        if hasattr(config, 'use_programs'):
            print(f"  use_programs: {config.use_programs}")
    else:
        print("  Could not read tokenizer config")

    # Load cache
    if not cache_path.exists():
        print(f"\nERROR: Cache not found at {cache_path}")
        print("Run: python -m midi.pretokenize")
        return 1

    print(f"\n--- Loading Token Cache ---")
    data = load_cache(cache_path)
    is_multitrack = data.get("multitrack", False)
    sequences = data["sequences"]
    file_count = data.get("file_count", "unknown")
    print(f"  Files tokenized: {file_count}")
    print(f"  Sequences: {len(sequences)}")
    print(f"  Multitrack: {is_multitrack}")

    if is_multitrack:
        print("\n  (Multitrack cache detected - extracting token lists)")
        raw_sequences = []
        for item in sequences:
            if isinstance(item, (list, tuple)) and len(item) >= 1:
                tokens = item[0] if isinstance(item[0], list) else item
                raw_sequences.append(tokens)
        sequences = raw_sequences

    # Limit sequences if requested
    if args.num_sequences:
        sequences = sequences[:args.num_sequences]
        print(f"  Analyzing first {len(sequences)} sequences")

    # Sequence length stats
    lengths = [len(s) for s in sequences]
    if not lengths:
        print("\nERROR: No sequences in cache!")
        return 1

    print(f"\n--- Sequence Length Stats ---")
    print(f"  Total sequences: {len(lengths)}")
    print(f"  Min: {min(lengths)}")
    print(f"  Max: {max(lengths)}")
    print(f"  Mean: {sum(lengths) / len(lengths):.0f}")
    print(f"  Median: {sorted(lengths)[len(lengths) // 2]}")

    # How many would be dropped at various seq_lengths
    for sl in [512, 1024, 2048, 4096, 8192]:
        usable = sum(1 for l in lengths if l > sl)
        pct = usable / len(lengths) * 100
        print(f"  Usable at seq_length={sl}: {usable}/{len(lengths)} ({pct:.1f}%)")

    # Check for bar resets (track concatenation bug)
    print(f"\n--- Bar Reset Check (Track Concatenation Bug) ---")
    total_resets = 0
    sequences_with_resets = 0
    for i, seq in enumerate(sequences):
        resets = check_bar_resets(seq, id_to_token)
        if resets:
            total_resets += len(resets)
            sequences_with_resets += 1
            if sequences_with_resets <= 3:
                print(f"  Sequence {i} (len={len(seq)}): {len(resets)} reset(s)")
                for pos, prev_bar, new_bar in resets[:3]:
                    print(f"    Position {pos}: Bar_{prev_bar} -> Bar_{new_bar}")

    if total_resets > 0:
        print(f"\n  *** PROBLEM DETECTED ***")
        print(f"  {sequences_with_resets}/{len(sequences)} sequences have bar resets ({total_resets} total)")
        print(f"  This means tracks were concatenated naively (time jumps backwards).")
        print(f"  The model is learning broken timing patterns.")
        print(f"  FIX: Set one_token_stream_for_programs=True in tokenizer config,")
        print(f"       then re-run pretokenize.py")
    else:
        print(f"  No bar resets found - track interleaving looks correct!")

    # Token ordering check
    print(f"\n--- REMI Token Ordering Check ---")
    total_violations = 0
    total_pitches = 0
    for seq in sequences[:100]:  # Check first 100 sequences
        v, p = check_token_ordering(seq, id_to_token)
        total_violations += v
        total_pitches += p

    if total_pitches > 0:
        violation_rate = total_violations / total_pitches * 100
        print(f"  Checked {min(100, len(sequences))} sequences")
        print(f"  Pitch tokens: {total_pitches}")
        print(f"  Ordering violations (Pitch not followed by Velocity): {total_violations} ({violation_rate:.1f}%)")
        if violation_rate > 10:
            print(f"  *** WARNING: High violation rate suggests tokenization issues ***")
        else:
            print(f"  Token ordering looks normal.")

    # Token type distribution
    print(f"\n--- Token Type Distribution (first 10 sequences) ---")
    combined = Counter()
    for seq in sequences[:10]:
        combined += analyze_sequence(seq, id_to_token)

    total_tokens = sum(combined.values())
    for token_type, count in combined.most_common(20):
        pct = count / total_tokens * 100
        print(f"  {token_type:25s}: {count:8d} ({pct:5.1f}%)")

    # Check first sequence tokens (to see tag placement)
    print(f"\n--- First Sequence (first 30 tokens) ---")
    if sequences:
        first_seq = sequences[0]
        for i, tid in enumerate(first_seq[:30]):
            name = id_to_token.get(tid, f"UNK_{tid}")
            print(f"  [{i:3d}] ID={tid:5d}  {name}")

    # Check for out-of-vocabulary tokens
    print(f"\n--- Out-of-Vocabulary Check ---")
    oov_count = 0
    oov_ids = set()
    for seq in sequences:
        for tid in seq:
            if tid < 0 or tid >= vocab_size:
                oov_count += 1
                oov_ids.add(tid)

    if oov_count > 0:
        print(f"  *** PROBLEM: {oov_count} out-of-vocabulary tokens found ***")
        print(f"  OOV IDs: {sorted(oov_ids)[:20]}")
    else:
        print(f"  All tokens within vocabulary range [0, {vocab_size})")

    # Summary
    print(f"\n{'='*50}")
    print(f"SUMMARY")
    print(f"{'='*50}")
    issues = []
    if total_resets > 0:
        issues.append("BAR RESETS: Tracks concatenated with time jumps (major)")
    if total_pitches > 0 and total_violations / total_pitches > 0.1:
        issues.append("TOKEN ORDERING: High Pitch->Velocity violation rate")
    if oov_count > 0:
        issues.append("OOV TOKENS: Model may produce garbage for these IDs")
    if max(lengths) < 2048:
        issues.append("SHORT SEQUENCES: All sequences < 2048 tokens")

    if issues:
        print("Issues found:")
        for issue in issues:
            print(f"  - {issue}")
    else:
        print("No data issues found.")
        print("Chaotic output is likely due to:")
        print("  - Model not converged (val loss 2.80 -> aim for <2.0)")
        print("  - Try lower temperature: --creativity 0.7")
        print("  - Try tighter sampling: --top-k 30 --top-p 0.90")

    return 0


if __name__ == "__main__":
    exit(main())
