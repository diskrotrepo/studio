#!/usr/bin/env python3
"""
Sample random MIDI files by genre from midi_metadata.json.

Creates a subset directory with symlinks to original MIDI files and a
filtered metadata JSON, ready to feed into pretokenize.py and train.py.

Examples:
    # List all genres and file counts
    python scripts/sample_by_genre.py --list-genres

    # Sample 3000 random electronic files
    python scripts/sample_by_genre.py --genre electronic --count 3000

    # Sample 1000 from each of multiple genres
    python scripts/sample_by_genre.py --genre electronic --genre rock --count 1000

    # Sample 500 from every genre
    python scripts/sample_by_genre.py --all-genres --count 500

    # Use a specific output directory and seed
    python scripts/sample_by_genre.py --genre jazz --count 200 --output-dir midi_jazz --seed 123

Then tokenize and train on the subset:
    python pretokenize.py --midi-dir midi_subset --metadata midi_subset/midi_metadata.json
    python train.py --midi-dir midi_subset
"""

from __future__ import annotations

import argparse
import json
import os
import random
import sys
from collections import defaultdict
from pathlib import Path


def load_metadata(metadata_path: Path) -> dict:
    """Load the midi_metadata.json file."""
    print(f"Loading metadata from {metadata_path}...")
    with open(metadata_path, "r") as f:
        data = json.load(f)
    print(f"  {data['stats']['total_files']} total files, "
          f"{data['stats']['tagged_files']} tagged, "
          f"{data['stats']['untagged_files']} untagged")
    return data


def build_genre_index(metadata: dict) -> dict[str, list[str]]:
    """
    Build a mapping of genre -> list of filenames.

    Each file can appear under multiple genres.
    """
    genre_to_files: dict[str, list[str]] = defaultdict(list)

    for filename, info in metadata["files"].items():
        genres = info.get("genres", [])
        if not genres:
            genre_to_files["UNTAGGED"].append(filename)
        for genre in genres:
            genre_to_files[genre].append(filename)

    return dict(genre_to_files)


def normalize_genre(genre_input: str, available_genres: list[str]) -> str | None:
    """
    Normalize a user-provided genre string to match metadata format.

    Accepts: "electronic", "Electronic", "ELECTRONIC", "GENRE_ELECTRONIC"
    Returns: "GENRE_ELECTRONIC" or None if not found.
    """
    # Already in correct format
    upper = genre_input.upper()
    if upper in available_genres:
        return upper

    # Try adding GENRE_ prefix
    with_prefix = f"GENRE_{upper}"
    if with_prefix in available_genres:
        return with_prefix

    # Try with underscores replacing spaces/hyphens
    sanitized = upper.replace(" ", "_").replace("-", "_")
    with_prefix = f"GENRE_{sanitized}"
    if with_prefix in available_genres:
        return with_prefix

    # Fuzzy: check if input is a substring of any genre
    matches = [g for g in available_genres if upper in g]
    if len(matches) == 1:
        return matches[0]

    return None


def print_genre_table(genre_index: dict[str, list[str]]) -> None:
    """Print a formatted table of genres and file counts."""
    # Sort by count descending
    sorted_genres = sorted(genre_index.items(), key=lambda x: -len(x[1]))

    total_tagged = sum(len(files) for genre, files in sorted_genres if genre != "UNTAGGED")
    untagged = len(genre_index.get("UNTAGGED", []))

    # Find the longest genre name for formatting
    max_name_len = max(len(g) for g in genre_index)

    print()
    print(f"{'Genre':<{max_name_len}}   {'Count':>7}   {'% of tagged':>11}")
    print(f"{'─' * max_name_len}   {'─' * 7}   {'─' * 11}")

    for genre, files in sorted_genres:
        if genre == "UNTAGGED":
            continue
        count = len(files)
        pct = count / total_tagged * 100 if total_tagged > 0 else 0
        # Strip GENRE_ prefix for cleaner display
        display_name = genre.replace("GENRE_", "").replace("_", " ").title()
        print(f"{display_name:<{max_name_len}}   {count:>7,}   {pct:>10.1f}%")

    print(f"{'─' * max_name_len}   {'─' * 7}   {'─' * 11}")
    print(f"{'Total tagged':<{max_name_len}}   {total_tagged:>7,}")
    if untagged > 0:
        print(f"{'Untagged':<{max_name_len}}   {untagged:>7,}")
    print()
    print("Note: files can belong to multiple genres, so counts may sum to more than total.")
    print()


def sample_files(
    genre_index: dict[str, list[str]],
    genres: list[str],
    count: int,
    seed: int | None = None,
) -> dict[str, list[str]]:
    """
    Sample `count` random files for each requested genre.

    Returns a dict of genre -> sampled filenames.
    """
    rng = random.Random(seed)
    sampled: dict[str, list[str]] = {}

    for genre in genres:
        available = genre_index.get(genre, [])
        if not available:
            print(f"  WARNING: genre '{genre}' has no files, skipping")
            continue

        n = min(count, len(available))
        if n < count:
            print(f"  WARNING: genre '{genre}' has only {len(available)} files "
                  f"(requested {count}), using all of them")

        sampled[genre] = rng.sample(available, n)
        display_name = genre.replace("GENRE_", "").replace("_", " ").title()
        print(f"  Sampled {n:,} files from {display_name}")

    return sampled


def create_subset_directory(
    sampled: dict[str, list[str]],
    metadata: dict,
    midi_dir: Path,
    output_dir: Path,
    use_symlinks: bool = True,
) -> int:
    """
    Create a subset directory with symlinks (or copies) and filtered metadata.

    Returns the number of files linked/copied.
    """
    output_dir.mkdir(parents=True, exist_ok=True)

    # Deduplicate filenames across genres
    all_filenames: set[str] = set()
    for files in sampled.values():
        all_filenames.update(files)

    print(f"\n  {len(all_filenames):,} unique files across all sampled genres")

    # Create symlinks or copy files
    linked = 0
    missing = 0
    for filename in sorted(all_filenames):
        src = midi_dir / filename
        dst = output_dir / filename

        if not src.exists():
            missing += 1
            continue

        if dst.exists() or dst.is_symlink():
            dst.unlink()

        if use_symlinks:
            # Use absolute path for symlink target
            os.symlink(src.resolve(), dst)
        else:
            import shutil
            shutil.copy2(src, dst)

        linked += 1

    if missing > 0:
        print(f"  WARNING: {missing} source MIDI files not found in {midi_dir}")

    # Write filtered metadata
    filtered_files = {
        filename: metadata["files"][filename]
        for filename in all_filenames
        if filename in metadata["files"]
    }

    # Compute genre breakdown for the subset
    genre_counts: dict[str, int] = defaultdict(int)
    for info in filtered_files.values():
        for genre in info.get("genres", []):
            genre_counts[genre] += 1

    filtered_metadata = {
        "version": metadata.get("version", 1),
        "generated_at": metadata.get("generated_at", ""),
        "stats": {
            "total_files": len(filtered_files),
            "tagged_files": sum(1 for f in filtered_files.values() if f.get("genres")),
            "untagged_files": sum(1 for f in filtered_files.values() if not f.get("genres")),
        },
        "sample_info": {
            "sampled_genres": {
                genre.replace("GENRE_", "").replace("_", " ").title(): len(files)
                for genre, files in sampled.items()
            },
            "unique_files": len(all_filenames),
            "genre_distribution": {
                genre.replace("GENRE_", "").replace("_", " ").title(): count
                for genre, count in sorted(genre_counts.items(), key=lambda x: -x[1])
            },
        },
        "files": filtered_files,
    }

    metadata_path = output_dir / "midi_metadata.json"
    with open(metadata_path, "w") as f:
        json.dump(filtered_metadata, f, indent=2)

    print(f"  Metadata written to {metadata_path}")

    return linked


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Sample random MIDI files by genre for training",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --list-genres
  %(prog)s --genre electronic --count 3000
  %(prog)s --genre electronic --genre rock --count 1000
  %(prog)s --all-genres --count 500
  %(prog)s --genre jazz --count 200 --output-dir midi_jazz --seed 42
        """,
    )

    parser.add_argument(
        "--metadata",
        type=str,
        default="midi_files/midi_metadata.json",
        help="Path to midi_metadata.json (default: midi_files/midi_metadata.json)",
    )
    parser.add_argument(
        "--midi-dir",
        type=str,
        default="midi_files",
        help="Directory containing source MIDI files (default: midi_files)",
    )
    parser.add_argument(
        "--list-genres",
        action="store_true",
        help="List all available genres and their file counts, then exit",
    )
    parser.add_argument(
        "--genre",
        type=str,
        action="append",
        dest="genres",
        help="Genre to sample from (can be specified multiple times). "
             "Accepts: 'electronic', 'Electronic', 'GENRE_ELECTRONIC', etc.",
    )
    parser.add_argument(
        "--all-genres",
        action="store_true",
        help="Sample from every genre",
    )
    parser.add_argument(
        "--count",
        type=int,
        default=1000,
        help="Number of files to sample per genre (default: 1000)",
    )
    parser.add_argument(
        "--output-dir",
        type=str,
        default="midi_subset",
        help="Output directory for the subset (default: midi_subset)",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=42,
        help="Random seed for reproducibility (default: 42)",
    )
    parser.add_argument(
        "--copy",
        action="store_true",
        help="Copy files instead of creating symlinks",
    )
    parser.add_argument(
        "--include-untagged",
        action="store_true",
        help="When using --all-genres, also include untagged files",
    )

    args = parser.parse_args()

    # Load metadata
    metadata_path = Path(args.metadata)
    if not metadata_path.exists():
        print(f"Error: metadata file not found: {metadata_path}", file=sys.stderr)
        return 1

    metadata = load_metadata(metadata_path)

    # Build genre index
    genre_index = build_genre_index(metadata)

    # List genres mode
    if args.list_genres:
        print_genre_table(genre_index)
        return 0

    # Validate arguments
    if not args.genres and not args.all_genres:
        parser.error("Specify --genre GENRE [--genre GENRE2 ...] or --all-genres (or use --list-genres)")

    # Resolve genres
    available = list(genre_index.keys())

    if args.all_genres:
        target_genres = [g for g in available if g != "UNTAGGED"]
        if args.include_untagged and "UNTAGGED" in available:
            target_genres.append("UNTAGGED")
        target_genres.sort()
    else:
        target_genres = []
        for g in args.genres:
            normalized = normalize_genre(g, available)
            if normalized is None:
                # Show helpful error with available genres
                genre_names = [
                    g.replace("GENRE_", "").lower()
                    for g in available
                    if g != "UNTAGGED"
                ]
                print(f"Error: unknown genre '{g}'", file=sys.stderr)
                print(f"Available genres: {', '.join(sorted(genre_names))}", file=sys.stderr)
                return 1
            target_genres.append(normalized)

    # Sample
    print(f"\nSampling {args.count:,} files per genre (seed={args.seed}):")
    sampled = sample_files(genre_index, target_genres, args.count, seed=args.seed)

    if not sampled:
        print("No files sampled!", file=sys.stderr)
        return 1

    # Create output directory
    midi_dir = Path(args.midi_dir)
    output_dir = Path(args.output_dir)
    link_type = "Copying" if args.copy else "Symlinking"
    print(f"\n{link_type} files to {output_dir}/")

    linked = create_subset_directory(
        sampled, metadata, midi_dir, output_dir,
        use_symlinks=not args.copy,
    )

    # Summary
    total_sampled = sum(len(files) for files in sampled.values())
    unique_files = len(set(f for files in sampled.values() for f in files))

    print(f"\n{'=' * 50}")
    print(f"SAMPLING COMPLETE")
    print(f"{'=' * 50}")
    print(f"  Genres sampled: {len(sampled)}")
    print(f"  Total samples: {total_sampled:,} (across genres, with overlap)")
    print(f"  Unique files: {unique_files:,}")
    print(f"  Files created: {linked:,}")
    print(f"  Output directory: {output_dir}/")
    print()
    print(f"Next steps:")
    print(f"  python pretokenize.py --midi-dir {output_dir} --metadata {output_dir}/midi_metadata.json")
    print(f"  python train.py --midi-dir {output_dir}")
    print()

    return 0


if __name__ == "__main__":
    sys.exit(main())
