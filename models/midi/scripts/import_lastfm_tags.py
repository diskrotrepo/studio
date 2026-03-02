"""
Import tags from the MSD Last.fm tag dataset (lastfm_tags.db) into track_metadata.db.

Download lastfm_tags.db from:
  http://labrosa.ee.columbia.edu/millionsong/sites/default/files/lastfm/lastfm_tags.db

Usage:
  python3 import_lastfm_tags.py [path/to/lastfm_tags.db]
"""

import os
import sqlite3
import sys

_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB_PATH = os.path.join(_ROOT, "track_metadata.db")
LASTFM_PATH = sys.argv[1] if len(sys.argv) > 1 else os.path.join(_ROOT, "lastfm_tags.db")


def main():
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

    conn.execute(f"ATTACH DATABASE ? AS lastfm", (LASTFM_PATH,))

    # Build a mapping of tid_rowid -> MSD track_id
    # lastfm_tags.db schema: tids(tid TEXT), tags(tag TEXT), tid_tag(tid INT, tag INT, val REAL)
    print("Querying joined tags...")
    rows = conn.execute(
        """
        SELECT t.tid, tags.tag, tt.val
        FROM lastfm.tids t
        JOIN lastfm.tid_tag tt ON tt.tid = t.ROWID
        JOIN lastfm.tags tags ON tags.ROWID = tt.tag
        JOIN songs s ON s.track_id = t.tid
        LEFT JOIN song_tags st ON st.track_id = t.tid
        WHERE st.track_id IS NULL
        ORDER BY t.tid, tt.val DESC
    """
    ).fetchall()

    print(f"Tag rows from Last.fm dataset: {len(rows)}")

    # Group tags by track_id, already sorted by val DESC
    current_tid = None
    current_tags = []
    inserted = 0

    def flush():
        nonlocal inserted
        if not current_tid or not current_tags:
            return
        top_tag = current_tags[0]
        all_tags = ",".join(current_tags)
        conn.execute(
            "INSERT OR REPLACE INTO song_tags (track_id, top_tag, all_tags) VALUES (?, ?, ?)",
            (current_tid, top_tag, all_tags),
        )
        inserted += 1
        if inserted % 10000 == 0:
            conn.commit()
            print(f"  Inserted {inserted}...")

    for tid, tag, val in rows:
        if tid != current_tid:
            flush()
            current_tid = tid
            current_tags = []
        current_tags.append(tag.lower())

    flush()

    conn.commit()
    conn.execute("DETACH DATABASE lastfm")
    conn.close()

    print(f"Done. Inserted tags for {inserted} tracks.")


if __name__ == "__main__":
    main()
