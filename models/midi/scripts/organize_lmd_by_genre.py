"""
Build a flat MIDI directory with JSON tag metadata from the LMD dataset.

Reads track metadata and Last.fm tags from track_metadata.db, copies MIDI files
to a flat output directory, and generates a midi_metadata.json file mapping each
filename to its pre-mapped tokenizer tags.

Usage:
    python organize_lmd_by_genre.py
    python organize_lmd_by_genre.py --skip-existing  # only copy new files
"""

import argparse
import json
import os
import shutil
import sqlite3
import sys
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from midi.tokenization.lastfm_tags import map_lastfm_tags

# -------- CONFIG --------
_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LMD_DIR = os.path.join(_ROOT, "lmd_matched")
DB_PATH = os.path.join(_ROOT, "track_metadata.db")
OUTPUT_DIR = os.path.join(_ROOT, "midi_files")
# ------------------------


def collect_midi_files(root_dir):
    midi_files = []
    for root, _, files in os.walk(root_dir):
        for f in files:
            if f.lower().endswith(".mid"):
                midi_files.append(os.path.join(root, f))
    return midi_files


def extract_track_id(midi_path):
    """Extract MSD track ID from parent directory name."""
    return os.path.basename(os.path.dirname(midi_path))


def make_flat_filename(midi_path):
    """Generate unique flat filename: {track_id}_{hash_prefix}.mid"""
    track_id = extract_track_id(midi_path)
    midi_hash = os.path.splitext(os.path.basename(midi_path))[0][:8]
    return f"{track_id}_{midi_hash}.mid"


def tags_only_mode():
    """Query DB for all tracks and dump mapped tags as JSON to stdout."""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute(
        """
        SELECT s.track_id, s.artist_name, s.title, st.all_tags
        FROM songs s
        LEFT JOIN song_tags st ON s.track_id = st.track_id
        WHERE st.all_tags IS NOT NULL AND st.all_tags != ''
        """
    )

    results = {}
    for track_id, artist_name, title, all_tags in cursor:
        mapped = map_lastfm_tags(all_tags)
        if not mapped["genres"] and not mapped["moods"]:
            continue
        results[track_id] = {
            "artist": artist_name or "",
            "title": title or "",
            "genres": mapped["genres"],
            "moods": mapped["moods"],
        }

    conn.close()
    print(json.dumps(results, indent=2))
    print(f"Total tracks with tags: {len(results)}", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(
        description="Build flat MIDI dir with JSON metadata"
    )
    parser.add_argument(
        "--skip-existing",
        action="store_true",
        help="Skip files already in output directory",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be done without copying files or writing metadata",
    )
    parser.add_argument(
        "--tags-only",
        action="store_true",
        help="Output JSON tag metadata to stdout without copying files",
    )
    args = parser.parse_args()

    if args.tags_only:
        tags_only_mode()
        return

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    midi_files = collect_midi_files(LMD_DIR)
    if not args.dry_run:
        os.makedirs(OUTPUT_DIR, exist_ok=True)

    metadata = {
        "version": 1,
        "generated_at": datetime.now().isoformat(),
        "stats": {},
        "files": {},
    }

    copied = 0
    skipped = 0

    for midi_path in midi_files:
        new_filename = make_flat_filename(midi_path)
        dest_path = os.path.join(OUTPUT_DIR, new_filename)

        if args.dry_run:
            pass
        elif args.skip_existing and os.path.exists(dest_path):
            pass
        else:
            shutil.copy2(midi_path, dest_path)

        # Look up metadata from DB
        track_id = extract_track_id(midi_path)
        cursor.execute(
            """
            SELECT s.artist_name, s.title, s.year, st.top_tag, st.all_tags
            FROM songs s
            LEFT JOIN song_tags st ON s.track_id = st.track_id
            WHERE s.track_id = ?
            """,
            (track_id,),
        )

        row = cursor.fetchone()
        if not row:
            skipped += 1
            continue

        artist_name, title, year, top_tag, all_tags = row

        # Map Last.fm tags to tokenizer vocabulary
        mapped = map_lastfm_tags(all_tags) if all_tags else {"genres": [], "moods": []}

        metadata["files"][new_filename] = {
            "track_id": track_id,
            "artist": artist_name or "",
            "title": title or "",
            "year": year,
            "genres": mapped["genres"],
            "moods": mapped["moods"],
            "top_tag": top_tag or "",
            "all_tags_raw": all_tags or "",
        }

        copied += 1
        if copied % 1000 == 0:
            print(f"Processed: {copied}")

    conn.close()

    tagged = sum(1 for f in metadata["files"].values() if f["genres"])
    metadata["stats"] = {
        "total_files": copied,
        "tagged_files": tagged,
        "untagged_files": copied - tagged,
    }

    if args.dry_run:
        print(f"[DRY RUN] Would copy: {copied}, Skipped (no DB entry): {skipped}")
        print(f"[DRY RUN] Tagged: {tagged}, Untagged: {copied - tagged}")
    else:
        json_path = os.path.join(OUTPUT_DIR, "midi_metadata.json")
        with open(json_path, "w") as f:
            json.dump(metadata, f, indent=2)

        print(f"Finished")
        print(f"Copied: {copied}, Skipped (no DB entry): {skipped}")
        print(f"Tagged: {tagged}, Untagged: {copied - tagged}")
        print(f"Metadata: {json_path}")


if __name__ == "__main__":
    main()
