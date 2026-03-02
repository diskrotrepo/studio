"""
Propagate tags from tagged tracks to untagged tracks by the same artist.

For each untagged track, finds the most common top_tag and all_tags among
other tracks by the same artist and copies them over.

Usage:
    python3 propagate_artist_tags.py          # apply changes
    python3 propagate_artist_tags.py --dry-run # just show stats
"""

import argparse
import os
import sqlite3

_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB_PATH = os.path.join(_ROOT, "track_metadata.db")


def main():
    parser = argparse.ArgumentParser(description="Propagate artist-level tags to untagged tracks")
    parser.add_argument("--dry-run", action="store_true", help="Show stats without writing")
    args = parser.parse_args()

    conn = sqlite3.connect(DB_PATH)

    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS song_tags (
            track_id TEXT PRIMARY KEY,
            top_tag TEXT,
            all_tags TEXT
        )
    """
    )
    conn.commit()

    # Build artist -> (top_tag, all_tags) using the most common top_tag per artist
    print("Building artist tag map...")
    artist_tags = conn.execute(
        """
        SELECT s.artist_name, st.top_tag, st.all_tags, COUNT(*) as cnt
        FROM songs s
        JOIN song_tags st ON s.track_id = st.track_id
        WHERE st.top_tag IS NOT NULL AND st.all_tags IS NOT NULL AND st.all_tags != ''
        GROUP BY s.artist_name, st.top_tag, st.all_tags
        ORDER BY s.artist_name, cnt DESC
    """
    ).fetchall()

    # Keep only the most common tag combo per artist
    artist_map = {}
    for artist, top_tag, all_tags, cnt in artist_tags:
        if artist not in artist_map:
            artist_map[artist] = (top_tag, all_tags)

    print(f"Artists with tags: {len(artist_map)}")

    # Find untagged tracks
    untagged = conn.execute(
        """
        SELECT s.track_id, s.artist_name
        FROM songs s
        LEFT JOIN song_tags st ON s.track_id = st.track_id
        WHERE (st.track_id IS NULL OR st.all_tags IS NULL OR st.all_tags = '')
          AND s.artist_name IS NOT NULL
    """
    ).fetchall()

    print(f"Untagged tracks: {len(untagged)}")

    filled = 0
    skipped = 0

    for track_id, artist in untagged:
        if artist in artist_map:
            top_tag, all_tags = artist_map[artist]
            if not args.dry_run:
                conn.execute(
                    "INSERT OR REPLACE INTO song_tags (track_id, top_tag, all_tags) VALUES (?, ?, ?)",
                    (track_id, top_tag, all_tags),
                )
            filled += 1
        else:
            skipped += 1

        if (filled + skipped) % 50000 == 0:
            if not args.dry_run:
                conn.commit()
            print(f"  Progress: {filled + skipped}/{len(untagged)} (filled: {filled}, no artist match: {skipped})")

    if not args.dry_run:
        conn.commit()

    conn.close()

    prefix = "[DRY RUN] " if args.dry_run else ""
    print(f"{prefix}Filled: {filled}, No artist match: {skipped}")


if __name__ == "__main__":
    main()
