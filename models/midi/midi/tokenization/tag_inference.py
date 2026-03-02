"""
Tag inference engine for MIDI files.

Infers conditioning tags from JSON metadata, folder structure,
file path keywords, and MIDI content analysis.
"""

import json
from pathlib import Path

from symusic import Score

from .tags import GENRE_TAGS, ARTIST_TAGS

# Cached JSON metadata (loaded once per process)
_metadata_cache: dict | None = None
_metadata_cache_path: Path | None = None


def infer_tempo_from_midi(midi_path: Path) -> str | None:
    """Infer tempo category (slow/medium/fast) from MIDI file."""
    try:
        score = Score(str(midi_path))
        # Get tempo from the score (in BPM)
        if score.tempos:
            # Use the first tempo marking
            bpm = score.tempos[0].qpm
        else:
            # Estimate from note density if no tempo marking
            total_notes = sum(len(track.notes) for track in score.tracks)
            duration_seconds = score.end() / score.ticks_per_quarter / 120 * 60
            if duration_seconds > 0:
                notes_per_second = total_notes / duration_seconds
                # Rough BPM estimate from note density
                bpm = notes_per_second * 15  # Heuristic multiplier
            else:
                return None

        # Categorize tempo
        if bpm < 80:
            return "TEMPO_SLOW"
        elif bpm < 140:
            return "TEMPO_MEDIUM"
        else:
            return "TEMPO_FAST"
    except Exception:
        return None


def extract_midi_attributes(midi_path: Path) -> list[str]:
    """
    Extract rich musical attributes from MIDI file content.

    Returns list of tag strings for conditioning (e.g., "KEY_MAJOR", "DENSITY_SPARSE").
    Covers all three phases of enrichment:
    - Phase 1: Key, time signature, density, dynamics, length
    - Phase 2: Register, arrangement, rhythm, harmony
    - Phase 3: Articulation, expression, era
    """
    try:
        score = Score(str(midi_path))
        tags = []

        # Skip if no tracks or notes
        if not score.tracks:
            return tags

        all_notes = [(n, t) for t in score.tracks for n in t.notes]
        if not all_notes:
            return tags

        # ========== Phase 1: Core Musical Attributes ==========

        # Key signature
        if hasattr(score, 'key_signatures') and score.key_signatures:
            ks = score.key_signatures[0]
            # mode: 0 = major, 1 = minor (standard MIDI convention)
            if hasattr(ks, 'mode'):
                tags.append("KEY_MINOR" if ks.mode else "KEY_MAJOR")

        # Time signature
        if hasattr(score, 'time_signatures') and score.time_signatures:
            ts = score.time_signatures[0]
            sig = f"{ts.numerator}_{ts.denominator}"
            known_sigs = ["4_4", "3_4", "6_8", "2_4", "5_4", "7_8", "12_8"]
            if sig in known_sigs:
                tags.append(f"TIMESIG_{sig.upper()}")
            else:
                tags.append("TIMESIG_OTHER_TIME")

        # Note density (notes per beat)
        total_notes = len(all_notes)
        ticks_per_beat = score.ticks_per_quarter if hasattr(score, 'ticks_per_quarter') else 480
        duration_beats = score.end() / ticks_per_beat if score.end() > 0 else 1
        density = total_notes / max(1, duration_beats)

        if density < 2:
            tags.append("DENSITY_SPARSE")
        elif density < 8:
            tags.append("DENSITY_MODERATE")
        else:
            tags.append("DENSITY_DENSE")

        # Dynamic range (velocity analysis)
        velocities = [n.velocity for n, t in all_notes if hasattr(n, 'velocity')]
        if velocities:
            mean_vel = sum(velocities) / len(velocities)
            vel_range = max(velocities) - min(velocities)
            vel_std = (sum((v - mean_vel) ** 2 for v in velocities) / len(velocities)) ** 0.5

            if mean_vel < 50:
                tags.append("DYNAMICS_SOFT")
            elif mean_vel > 100:
                tags.append("DYNAMICS_LOUD")
            elif vel_range > 60 or vel_std > 25:
                tags.append("DYNAMICS_DYNAMIC")
            else:
                tags.append("DYNAMICS_MODERATE_DYNAMICS")

        # Piece length (in bars, assuming 4 beats per bar)
        bars = duration_beats / 4
        if bars < 32:
            tags.append("LENGTH_SHORT")
        elif bars < 128:
            tags.append("LENGTH_MEDIUM_LENGTH")
        else:
            tags.append("LENGTH_LONG")

        # ========== Phase 2: Structural Attributes ==========

        # Pitch range / register
        all_pitches = [n.pitch for n, t in all_notes if hasattr(n, 'pitch')]
        if all_pitches:
            pitch_range = max(all_pitches) - min(all_pitches)
            avg_pitch = sum(all_pitches) / len(all_pitches)

            if pitch_range > 48:  # More than 4 octaves
                tags.append("REGISTER_WIDE_RANGE")
            elif avg_pitch < 48:  # Below C3
                tags.append("REGISTER_LOW_REGISTER")
            elif avg_pitch > 72:  # Above C5
                tags.append("REGISTER_HIGH_REGISTER")
            else:
                tags.append("REGISTER_MID_REGISTER")

        # Arrangement size (based on active tracks)
        active_tracks = len([t for t in score.tracks if t.notes])
        if active_tracks == 1:
            tags.append("ARRANGEMENT_SOLO")
        elif active_tracks == 2:
            tags.append("ARRANGEMENT_DUO")
        elif active_tracks <= 5:
            tags.append("ARRANGEMENT_SMALL_ENSEMBLE")
        else:
            tags.append("ARRANGEMENT_FULL_ARRANGEMENT")

        # Rhythmic feel (analyze note onset distribution)
        if len(all_notes) > 10:
            onsets = sorted([n.time for n, t in all_notes if hasattr(n, 'time')])
            if onsets and ticks_per_beat > 0:
                # Check how many notes fall on beats vs off-beats
                on_beat_count = sum(1 for o in onsets if o % ticks_per_beat < ticks_per_beat * 0.1)
                off_beat_count = len(onsets) - on_beat_count
                beat_ratio = on_beat_count / len(onsets) if onsets else 0

                # Check for swing (notes consistently late)
                swing_positions = [o % ticks_per_beat for o in onsets]
                avg_position = sum(swing_positions) / len(swing_positions) if swing_positions else 0

                if beat_ratio > 0.7:
                    tags.append("RHYTHM_STRAIGHT")
                elif avg_position > ticks_per_beat * 0.55:  # Consistently late = swing
                    tags.append("RHYTHM_SWING")
                elif off_beat_count > on_beat_count:
                    tags.append("RHYTHM_SYNCOPATED")
                else:
                    tags.append("RHYTHM_COMPLEX_RHYTHM")

        # Harmonic complexity (unique pitch classes per bar)
        if all_pitches and bars > 0:
            # Count unique pitch classes (0-11) across the piece
            pitch_classes = set(p % 12 for p in all_pitches)
            avg_pitch_classes = len(pitch_classes)

            if avg_pitch_classes <= 5:
                tags.append("HARMONY_SIMPLE_HARMONY")
            elif avg_pitch_classes <= 8:
                tags.append("HARMONY_MODERATE_HARMONY")
            else:
                tags.append("HARMONY_COMPLEX_HARMONY")

        # ========== Phase 3: Expressive Attributes ==========

        # Articulation (note duration vs inter-onset interval)
        if len(all_notes) > 5:
            # Sort notes by start time
            sorted_notes = sorted(all_notes, key=lambda x: x[0].time if hasattr(x[0], 'time') else 0)
            legato_count = 0
            staccato_count = 0

            for i in range(len(sorted_notes) - 1):
                note, _ = sorted_notes[i]
                next_note, _ = sorted_notes[i + 1]

                if hasattr(note, 'duration') and hasattr(note, 'time') and hasattr(next_note, 'time'):
                    note_end = note.time + note.duration
                    next_start = next_note.time
                    gap = next_start - note_end

                    if gap <= 0:  # Overlapping or connected
                        legato_count += 1
                    elif note.duration < (next_start - note.time) * 0.5:
                        staccato_count += 1

            total_transitions = legato_count + staccato_count
            if total_transitions > 0:
                legato_ratio = legato_count / total_transitions
                if legato_ratio > 0.6:
                    tags.append("ARTICULATION_LEGATO")
                elif legato_ratio < 0.3:
                    tags.append("ARTICULATION_STACCATO")
                else:
                    tags.append("ARTICULATION_MIXED_ARTICULATION")

        # Expression (velocity variance + pitch bend presence)
        if velocities:
            vel_std = (sum((v - mean_vel) ** 2 for v in velocities) / len(velocities)) ** 0.5

            # Check for pitch bends
            has_pitch_bends = any(
                hasattr(t, 'pitch_bends') and t.pitch_bends
                for t in score.tracks
            )

            if vel_std < 10 and not has_pitch_bends:
                tags.append("EXPRESSION_MECHANICAL")
            elif vel_std > 25 or has_pitch_bends:
                tags.append("EXPRESSION_EXPRESSIVE")
                if vel_std > 35 and has_pitch_bends:
                    tags.append("EXPRESSION_HIGHLY_EXPRESSIVE")
            else:
                tags.append("EXPRESSION_EXPRESSIVE")

        # Era/Style (based on instrument programs used)
        programs_used = set()
        for track in score.tracks:
            if hasattr(track, 'program'):
                programs_used.add(track.program)

        synth_count = sum(1 for p in programs_used if 80 <= p <= 103)
        acoustic_count = sum(1 for p in programs_used if p < 32 or 40 <= p <= 79)

        if synth_count > acoustic_count and synth_count > 0:
            tags.append("ERA_MODERN")
        elif acoustic_count > synth_count and acoustic_count > 0:
            tags.append("ERA_VINTAGE")
        else:
            tags.append("ERA_CONTEMPORARY")

        return tags

    except Exception:
        return []


def load_metadata(metadata_path: Path) -> dict:
    """
    Load JSON metadata file and cache it (one load per process).

    Returns the "files" dict mapping filename -> tag info.
    """
    global _metadata_cache, _metadata_cache_path
    if _metadata_cache is not None and _metadata_cache_path == metadata_path:
        return _metadata_cache

    with open(metadata_path) as f:
        data = json.load(f)

    _metadata_cache = data.get("files", {})
    _metadata_cache_path = metadata_path
    return _metadata_cache


def infer_tags_from_metadata(midi_path: Path, metadata: dict) -> list[str]:
    """
    Look up genre/mood tags from JSON metadata.

    Args:
        midi_path: Path to MIDI file (filename used as lookup key)
        metadata: The loaded metadata "files" dict

    Returns:
        List of tag strings like ['GENRE_HIP_HOP', 'GENRE_POP', 'MOOD_HAPPY']
    """
    filename = midi_path.name
    entry = metadata.get(filename)
    if not entry:
        return []

    tags = []
    tags.extend(entry.get("genres", []))
    tags.extend(entry.get("moods", []))
    return tags


def infer_tags_from_path(midi_path: Path, midi_root: Path = None, metadata: dict = None) -> list[str]:
    """
    Infer tags from metadata, folder structure, keywords, and MIDI content.

    Priority:
    1. JSON metadata (if metadata dict provided)
    2. Genre from folder (if structure is <genre>/<artist>/<file>.mid)
    3. Artist from folder (parent of MIDI file)
    4. Path keyword matching (fallback for genre/mood)
    5. Tempo from MIDI content (always attempted)
    6. MIDI content attributes (always attempted)

    Args:
        midi_path: Path to the MIDI file
        midi_root: Root directory of MIDI files (for folder structure detection)
        metadata: Loaded JSON metadata dict (from load_metadata)
    """
    tags = []

    # Try JSON metadata first (highest priority for genre/mood)
    if metadata is not None:
        metadata_tags = infer_tags_from_metadata(midi_path, metadata)
        tags.extend(metadata_tags)

    # Try to extract genre and artist from folder structure (only if no genre from metadata)
    if midi_root and not any(t.startswith("GENRE_") for t in tags):
        try:
            rel_path = midi_path.relative_to(midi_root)
            parts = rel_path.parts

            if len(parts) >= 3:
                # Structure: <genre>/<artist>/<file>.mid
                genre_folder = parts[0].lower().replace(' ', '_').replace('-', '_')
                artist_folder = parts[1].lower().replace(' ', '_').replace('-', '_')

                # Add genre tag from folder name
                genre_tag = f"GENRE_{genre_folder.upper()}"
                # Check if it's a known genre or add it dynamically
                if any(genre_folder in g.lower() for g in GENRE_TAGS) or genre_folder.upper() in [
                    "ROCK", "METAL", "POP", "ELECTRONIC", "HIP_HOP", "R&B_SOUL",
                    "JAZZ", "CLASSICAL", "COUNTRY", "BLUES", "REGGAE", "LATIN",
                    "WORLD", "SOUNDTRACK", "EASY_LISTENING", "UNKNOWN"
                ]:
                    tags.append(genre_tag)

                # Add artist tag
                if artist_folder in ARTIST_TAGS:
                    artist_tag = f"ARTIST_{artist_folder.upper()}"
                    tags.append(artist_tag)

            elif len(parts) == 2:
                # Structure: <artist>/<file>.mid (flat structure)
                artist_folder = parts[0].lower().replace(' ', '_').replace('-', '_')
                if artist_folder in ARTIST_TAGS:
                    artist_tag = f"ARTIST_{artist_folder.upper()}"
                    tags.append(artist_tag)

        except ValueError:
            pass  # midi_path is not relative to midi_root

    # Fall back to path-based inference if no genre found
    if not any(t.startswith("GENRE_") for t in tags):
        path_lower = str(midi_path).lower()
        genre_keywords = {
            "classical": ["classical", "symphony", "sonata", "concerto", "opus", "orchestral"],
            "jazz": ["jazz", "swing", "bebop"],
            "rock": ["rock", "metal", "punk", "grunge"],
            "pop": ["pop", "disco", "dance"],
            "electronic": ["electronic", "techno", "house", "edm", "synth", "trance"],
            "ambient": ["ambient", "chill", "relax", "meditation"],
            "folk": ["folk", "country", "acoustic", "traditional"],
            "blues": ["blues", "soul", "r&b", "rnb"],
        }
        for genre, keywords in genre_keywords.items():
            if any(kw in path_lower for kw in keywords):
                tags.append(f"GENRE_{genre.upper()}")
                break

    # Fall back to path-based mood if no mood found
    if not any(t.startswith("MOOD_") for t in tags):
        path_lower = str(midi_path).lower()
        mood_keywords = {
            "happy": ["happy", "joy", "fun", "bright", "cheerful"],
            "sad": ["sad", "melancholy", "sorrow", "tragic", "grief"],
            "energetic": ["energetic", "power", "intense", "wild"],
            "calm": ["calm", "peaceful", "gentle", "soft", "quiet"],
            "dark": ["dark", "evil", "sinister", "horror", "scary"],
            "uplifting": ["uplifting", "inspiring", "hope", "triumph"],
        }
        for mood, keywords in mood_keywords.items():
            if any(kw in path_lower for kw in keywords):
                tags.append(f"MOOD_{mood.upper()}")
                break

    # Always try to infer tempo from MIDI content
    tempo_tag = infer_tempo_from_midi(midi_path)
    if tempo_tag:
        tags.append(tempo_tag)

    # Extract rich musical attributes from MIDI content (all phases)
    midi_attributes = extract_midi_attributes(midi_path)
    tags.extend(midi_attributes)

    return tags
