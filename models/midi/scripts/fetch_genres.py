import os
import sqlite3
import time
import threading
import urllib.request
import urllib.parse
import json
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed

# -------- CONFIG --------
_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB_PATH = os.path.join(_ROOT, "track_metadata.db")
API_KEY = os.environ.get("LASTFM_API_KEY", "")  # Get one free at https://www.last.fm/api/account/create
RATE_LIMIT = 0.2  # seconds between requests (5 req/s)
MAX_WORKERS = 4  # concurrent threads
# ------------------------

# In-memory cache: artist_name -> (top_tag, all_tags)
_artist_cache = {}
_cache_lock = threading.Lock()

# Rate limiter: serialise timing so total throughput stays ≤ 5 req/s
_rate_lock = threading.Lock()
_last_request_time = 0.0


def setup_genre_table(conn):
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


def _parse_tags(data):
    if "toptags" not in data or "tag" not in data["toptags"]:
        return None, None

    tags = data["toptags"]["tag"]
    if not tags:
        return None, None

    tag_names = [t["name"].lower() for t in tags if int(t.get("count", 0)) > 0]
    if not tag_names:
        tag_names = [tags[0]["name"].lower()]

    return tag_names[0], ",".join(tag_names)


def _api_call(params):
    global _last_request_time
    with _rate_lock:
        now = time.monotonic()
        wait = RATE_LIMIT - (now - _last_request_time)
        if wait > 0:
            time.sleep(wait)
        _last_request_time = time.monotonic()
    url = f"https://ws.audioscrobbler.com/2.0/?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(url, headers={"User-Agent": "midi-genre-tagger/1.0"})
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read())


def fetch_artist_tags(artist):
    with _cache_lock:
        if artist in _artist_cache:
            return _artist_cache[artist]

    try:
        data = _api_call({
            "method": "artist.getTopTags",
            "artist": artist,
            "api_key": API_KEY,
            "format": "json",
        })
        top, all_tags = _parse_tags(data)
        with _cache_lock:
            _artist_cache[artist] = (top, all_tags)
        return top, all_tags
    except Exception as e:
        print(f"  Error fetching artist {artist}: {e}")
        with _cache_lock:
            _artist_cache[artist] = (None, None)
        return None, None


def main():
    if not API_KEY:
        print("Set your Last.fm API key in fetch_genres.py (API_KEY variable)")
        print("Get one free at: https://www.last.fm/api/account/create")
        sys.exit(1)

    conn = sqlite3.connect(DB_PATH)
    setup_genre_table(conn)

    # Get unique artists that have untagged tracks
    artists = conn.execute(
        """
        SELECT DISTINCT s.artist_name
        FROM songs s
        LEFT JOIN song_tags st ON s.track_id = st.track_id
        WHERE st.track_id IS NULL
          AND s.artist_name IS NOT NULL
    """
    ).fetchall()
    artists = [a[0] for a in artists]

    total = len(artists)
    print(f"Unique artists to fetch: {total}  (workers={MAX_WORKERS})")

    fetched = 0
    no_tags = 0
    start_time = time.monotonic()

    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
        futures = {pool.submit(fetch_artist_tags, a): a for a in artists}

        for future in as_completed(futures):
            artist = futures[future]
            top_tag, all_tags = future.result()

            if top_tag:
                fetched += 1
            else:
                no_tags += 1

            # Apply to all untagged tracks by this artist
            conn.execute(
                """
                INSERT OR REPLACE INTO song_tags (track_id, top_tag, all_tags)
                SELECT s.track_id, ?, ?
                FROM songs s
                LEFT JOIN song_tags st ON s.track_id = st.track_id
                WHERE st.track_id IS NULL AND s.artist_name = ?
                """,
                (top_tag, all_tags, artist),
            )

            done = fetched + no_tags
            if done % 100 == 0:
                conn.commit()
                elapsed = time.monotonic() - start_time
                rate = done / elapsed
                remaining = (total - done) / rate
                mins, secs = divmod(int(remaining), 60)
                hrs, mins = divmod(mins, 60)
                eta = f"{hrs}h{mins:02d}m" if hrs else f"{mins}m{secs:02d}s"
                print(f"Progress: {done}/{total} artists (tagged: {fetched}, no tags: {no_tags}) ETA: {eta}")

    conn.commit()
    conn.close()

    print(f"Done. Artists tagged: {fetched}, No tags: {no_tags}")


if __name__ == "__main__":
    main()
