from ..tokenization.tags import GENRE_TAGS, DISCOVERED_GENRES

# General MIDI program number to instrument name
GM_PROGRAM_NAMES = [
    "Acoustic Grand Piano", "Bright Acoustic Piano", "Electric Grand Piano", "Honky-tonk Piano",
    "Electric Piano 1", "Electric Piano 2", "Harpsichord", "Clavinet",
    "Celesta", "Glockenspiel", "Music Box", "Vibraphone",
    "Marimba", "Xylophone", "Tubular Bells", "Dulcimer",
    "Drawbar Organ", "Percussive Organ", "Rock Organ", "Church Organ",
    "Reed Organ", "Accordion", "Harmonica", "Tango Accordion",
    "Acoustic Guitar (nylon)", "Acoustic Guitar (steel)", "Electric Guitar (jazz)", "Electric Guitar (clean)",
    "Electric Guitar (muted)", "Overdriven Guitar", "Distortion Guitar", "Guitar Harmonics",
    "Acoustic Bass", "Electric Bass (finger)", "Electric Bass (pick)", "Fretless Bass",
    "Slap Bass 1", "Slap Bass 2", "Synth Bass 1", "Synth Bass 2",
    "Violin", "Viola", "Cello", "Contrabass",
    "Tremolo Strings", "Pizzicato Strings", "Orchestral Harp", "Timpani",
    "String Ensemble 1", "String Ensemble 2", "Synth Strings 1", "Synth Strings 2",
    "Choir Aahs", "Voice Oohs", "Synth Choir", "Orchestra Hit",
    "Trumpet", "Trombone", "Tuba", "Muted Trumpet",
    "French Horn", "Brass Section", "Synth Brass 1", "Synth Brass 2",
    "Soprano Sax", "Alto Sax", "Tenor Sax", "Baritone Sax",
    "Oboe", "English Horn", "Bassoon", "Clarinet",
    "Piccolo", "Flute", "Recorder", "Pan Flute",
    "Blown Bottle", "Shakuhachi", "Whistle", "Ocarina",
    "Lead 1 (square)", "Lead 2 (sawtooth)", "Lead 3 (calliope)", "Lead 4 (chiff)",
    "Lead 5 (charang)", "Lead 6 (voice)", "Lead 7 (fifths)", "Lead 8 (bass + lead)",
    "Pad 1 (new age)", "Pad 2 (warm)", "Pad 3 (polysynth)", "Pad 4 (choir)",
    "Pad 5 (bowed)", "Pad 6 (metallic)", "Pad 7 (halo)", "Pad 8 (sweep)",
    "FX 1 (rain)", "FX 2 (soundtrack)", "FX 3 (crystal)", "FX 4 (atmosphere)",
    "FX 5 (brightness)", "FX 6 (goblins)", "FX 7 (echoes)", "FX 8 (sci-fi)",
    "Sitar", "Banjo", "Shamisen", "Koto",
    "Kalimba", "Bagpipe", "Fiddle", "Shanai",
    "Tinkle Bell", "Agogo", "Steel Drums", "Woodblock",
    "Taiko Drum", "Melodic Tom", "Synth Drum", "Reverse Cymbal",
    "Guitar Fret Noise", "Breath Noise", "Seashore", "Bird Tweet",
    "Telephone Ring", "Helicopter", "Applause", "Gunshot",
]


GM_CATEGORIES = [
    {"name": "Piano", "programs": list(range(0, 8))},
    {"name": "Chromatic Percussion", "programs": list(range(8, 16))},
    {"name": "Organ", "programs": list(range(16, 24))},
    {"name": "Guitar", "programs": list(range(24, 32))},
    {"name": "Bass", "programs": list(range(32, 40))},
    {"name": "Strings", "programs": list(range(40, 48))},
    {"name": "Ensemble", "programs": list(range(48, 56))},
    {"name": "Brass", "programs": list(range(56, 64))},
    {"name": "Reed", "programs": list(range(64, 72))},
    {"name": "Pipe", "programs": list(range(72, 80))},
    {"name": "Synth Lead", "programs": list(range(80, 88))},
    {"name": "Synth Pad", "programs": list(range(88, 96))},
    {"name": "Synth Effects", "programs": list(range(96, 104))},
    {"name": "Ethnic", "programs": list(range(104, 112))},
    {"name": "Percussive", "programs": list(range(112, 120))},
    {"name": "Sound Effects", "programs": list(range(120, 128))},
]


def gm_program_name(program: int) -> str:
    """Return the General MIDI instrument name for a program number."""
    if program == -1:
        return "Drums"
    if 0 <= program < len(GM_PROGRAM_NAMES):
        return GM_PROGRAM_NAMES[program]
    return f"Program {program}"


def get_categorized_instruments():
    """Return instruments organized by GM category."""
    categories = []
    for cat in GM_CATEGORIES:
        instruments = [
            {"program": p, "name": GM_PROGRAM_NAMES[p]}
            for p in cat["programs"]
        ]
        categories.append({
            "category": cat["name"],
            "instruments": instruments,
        })
    # Drums as its own category
    categories.append({
        "category": "Drums",
        "instruments": [{"program": -1, "name": "Drums (Channel 10)"}],
    })
    return categories


# =========================================================================
# Genre-aware track types and instrument pools
# =========================================================================

# Default track layouts per genre (used when --track-types not specified)
GENRE_TRACK_DEFAULTS = {
    "jazz":          ["melody", "bass", "chords", "drums"],
    "classical":     ["melody", "strings", "chords", "bass"],
    "rock":          ["melody", "bass", "chords", "drums"],
    "metal":         ["melody", "bass", "chords", "drums"],
    "pop":           ["melody", "bass", "chords", "drums"],
    "electronic":    ["melody", "bass", "pad", "drums"],
    "hip_hop":       ["melody", "bass", "pad", "drums"],
    "blues":         ["melody", "bass", "chords", "drums"],
    "country":       ["melody", "bass", "chords", "drums"],
    "r&b_soul":      ["melody", "bass", "chords", "drums"],
    "latin":         ["melody", "bass", "chords", "drums"],
    "reggae":        ["melody", "bass", "chords", "drums"],
    "folk":          ["melody", "bass", "chords", "drums"],
    "ambient":       ["pad", "strings", "lead", "pad"],
    "soundtrack":    ["melody", "strings", "chords", "drums"],
    "world":         ["melody", "bass", "chords", "drums"],
    "easy_listening": ["melody", "bass", "chords", "strings"],
}

# Instrument pools per genre and track type (MIDI program numbers)
GENRE_INSTRUMENT_POOLS = {
    "jazz": {
        "melody":  [65, 66, 67, 56, 73, 0],   # Soprano/Tenor/Bari Sax, Trumpet, Flute, Piano
        "chords":  [0, 16, 26],                # Piano, Organ, Jazz Guitar
        "bass":    [32],                        # Acoustic Bass
        "drums":   [-1],
        "strings": [40, 42],                    # Violin, Cello
        "pad":     [88, 89],
        "lead":    [56, 65, 66],               # Trumpet, Sax
        "other":   [0, 11, 56, 65],            # Piano, Vibes, Trumpet, Sax
    },
    "classical": {
        "melody":  [40, 73, 68, 71, 0],        # Violin, Flute, Oboe, Clarinet, Piano
        "chords":  [0, 6, 48],                 # Piano, Harpsichord, String Ensemble
        "bass":    [42, 43],                    # Cello, Contrabass
        "drums":   [-1],
        "strings": [40, 41, 42, 48, 49],       # Violin, Viola, Cello, String Ensembles
        "pad":     [48, 49],                    # String Ensembles
        "lead":    [40, 73, 68],               # Violin, Flute, Oboe
        "other":   [0, 40, 73, 68],
    },
    "rock": {
        "melody":  [29, 30, 27, 0],            # Overdriven/Distortion/Clean Guitar, Piano
        "chords":  [29, 27, 0, 16],            # Overdriven/Clean Guitar, Piano, Organ
        "bass":    [33, 34],                    # Electric Bass (finger/pick)
        "drums":   [-1],
        "strings": [48, 49],
        "pad":     [89, 92],
        "lead":    [29, 30],                   # Overdriven/Distortion Guitar
        "other":   [29, 27, 0],
    },
    "metal": {
        "melody":  [29, 30],                   # Overdriven/Distortion Guitar
        "chords":  [29, 30],
        "bass":    [33, 34],                   # Electric Bass (finger/pick)
        "drums":   [-1],
        "strings": [48],
        "pad":     [92],
        "lead":    [29, 30],
        "other":   [29, 30],
    },
    "pop": {
        "melody":  [0, 4, 25, 80],            # Piano, E.Piano, Steel Guitar, Synth Lead
        "chords":  [0, 1, 4, 5, 16, 19, 24, 25, 26, 46, 48, 89],
        "bass":    [33, 38, 39],               # Electric Bass, Synth Bass
        "drums":   [-1],
        "strings": [48, 49],
        "pad":     [88, 89, 91],
        "lead":    [80, 81],
        "other":   [0, 4, 24],
    },
    "electronic": {
        "melody":  [80, 81, 82, 84],           # Synth Leads
        "chords":  [88, 89, 90, 4],            # Synth Pads, E.Piano
        "bass":    [38, 39, 87],               # Synth Bass, Lead Bass+Lead
        "drums":   [-1],
        "strings": [48, 50],
        "pad":     [88, 89, 90, 91, 92, 93, 94, 95],
        "lead":    [80, 81, 82, 83, 84, 85, 86, 87],
        "other":   [80, 88, 38],
    },
    "hip_hop": {
        "melody":  [0, 4, 80, 81],            # Piano, E.Piano, Synth Leads
        "chords":  [0, 4, 88, 89],            # Piano, E.Piano, Synth Pads
        "bass":    [38, 39, 87],               # Synth Bass
        "drums":   [-1],
        "strings": [48, 49],
        "pad":     [88, 89, 90, 91],
        "lead":    [80, 81],
        "other":   [0, 4, 80],
    },
    "blues": {
        "melody":  [25, 26, 22, 0],           # Guitar, Jazz Guitar, Harmonica, Piano
        "chords":  [0, 16, 24],               # Piano, Organ, Guitar
        "bass":    [32, 33],                   # Acoustic/Electric Bass
        "drums":   [-1],
        "strings": [40],
        "pad":     [89],
        "lead":    [25, 26, 22],
        "other":   [0, 25, 22],
    },
    "country": {
        "melody":  [25, 40, 24, 0],           # Steel Guitar, Fiddle, Guitar, Piano
        "chords":  [24, 25, 0],               # Guitars, Piano
        "bass":    [32, 33],                   # Acoustic/Electric Bass
        "drums":   [-1],
        "strings": [40, 45],                   # Fiddle, Pizzicato Strings
        "pad":     [89],
        "lead":    [25, 40],
        "other":   [24, 25, 0, 40],
    },
    "r&b_soul": {
        "melody":  [4, 0, 80],                # E.Piano, Piano, Synth Lead
        "chords":  [4, 5, 0, 26],             # E.Pianos, Piano, Jazz Guitar
        "bass":    [33, 36, 38],               # Electric Bass, Slap Bass, Synth Bass
        "drums":   [-1],
        "strings": [48, 49],
        "pad":     [88, 89],
        "lead":    [80, 4],
        "other":   [4, 0, 33],
    },
    "latin": {
        "melody":  [56, 73, 24],              # Trumpet, Flute, Guitar
        "chords":  [0, 24, 25],               # Piano, Guitars
        "bass":    [32],                       # Acoustic Bass
        "drums":   [-1],
        "strings": [40, 48],
        "pad":     [89],
        "lead":    [56, 73],
        "other":   [56, 0, 24],
    },
    "reggae": {
        "melody":  [24, 16, 0],               # Guitar, Organ, Piano
        "chords":  [24, 16, 0],               # Guitar, Organ, Piano
        "bass":    [32, 33],                   # Acoustic/Electric Bass
        "drums":   [-1],
        "strings": [48],
        "pad":     [89],
        "lead":    [24, 16],
        "other":   [24, 16, 0],
    },
    "folk": {
        "melody":  [25, 40, 73, 22],          # Steel Guitar, Violin, Flute, Harmonica
        "chords":  [24, 25, 0],               # Guitars, Piano
        "bass":    [32],                       # Acoustic Bass
        "drums":   [-1],
        "strings": [40, 42],
        "pad":     [89],
        "lead":    [25, 40, 73],
        "other":   [24, 25, 40, 73],
    },
    "ambient": {
        "melody":  [88, 89, 90],              # Pads used melodically
        "chords":  [88, 89, 90, 91, 92],      # Synth Pads
        "bass":    [38, 39],                   # Synth Bass
        "drums":   [-1],
        "strings": [48, 49, 50],              # String Ensembles, Synth Strings
        "pad":     [88, 89, 90, 91, 92, 93, 94, 95],
        "lead":    [80, 82, 85],
        "other":   [88, 89, 90],
    },
    "soundtrack": {
        "melody":  [40, 73, 68, 56, 0],       # Violin, Flute, Oboe, Trumpet, Piano
        "chords":  [0, 48, 49],               # Piano, String Ensembles
        "bass":    [42, 43],                   # Cello, Contrabass
        "drums":   [-1],
        "strings": [48, 49, 50, 51],          # String Ensembles
        "pad":     [48, 89, 92],
        "lead":    [40, 56, 73],
        "other":   [0, 48, 40],
    },
    "easy_listening": {
        "melody":  [0, 40, 73, 11],           # Piano, Violin, Flute, Vibes
        "chords":  [0, 24, 89],               # Piano, Guitar, Warm Pad
        "bass":    [32, 33],                   # Acoustic/Electric Bass
        "drums":   [-1],
        "strings": [40, 48, 49],
        "pad":     [88, 89],
        "lead":    [0, 73, 11],
        "other":   [0, 40, 73],
    },
    "world": {
        "melody":  [73, 75, 109, 104, 0],     # Flute, Pan Flute, Bagpipe, Sitar, Piano
        "chords":  [0, 24, 46],               # Piano, Guitar, Harp
        "bass":    [32],                       # Acoustic Bass
        "drums":   [-1],
        "strings": [40, 48, 104],             # Violin, Strings, Sitar
        "pad":     [89, 92],
        "lead":    [73, 75, 109],
        "other":   [73, 75, 0, 24],
    },
}

# Fallback generic pools (used when no genre tag is recognized)
GENERIC_INSTRUMENT_POOLS = {
    "melody":  [0, 1, 4, 6, 11, 24, 25, 40, 56, 65, 68, 73],
    "chords":  [0, 1, 4, 5, 16, 19, 24, 25, 26, 46, 48, 89],
    "bass":    [32, 33, 34, 35, 36, 37, 38, 39, 43, 87],
    "drums":   [-1],
    "strings": [40, 41, 42, 43, 44, 45, 48, 49, 50, 51],
    "pad":     [88, 89, 90, 91, 92, 93, 94, 95],
    "lead":    [80, 81, 82, 83, 84, 85, 86, 87],
    "other":   [0, 4, 11, 24, 40, 46, 48, 56, 65, 73],
}


TRACK_TYPE_ICONS = {
    "melody":  "music_note",
    "bass":    "graphic_eq",
    "chords":  "piano",
    "drums":   "drum",
    "pad":     "layers",
    "lead":    "queue_music",
    "strings": "violin",
    "other":   "library_music",
}


def get_track_type_instruments(genre: str | None = None):
    """Return instrument choices for each track type, optionally filtered by genre.

    Returns a dict mapping track type names to lists of
    ``{"program": int, "name": str}`` dicts.  When *genre* is provided and
    recognised, the genre-specific pool is used; otherwise the generic pool.
    """
    pools = GENRE_INSTRUMENT_POOLS.get(genre, GENERIC_INSTRUMENT_POOLS) if genre else GENERIC_INSTRUMENT_POOLS
    track_types = {}
    for track_type, programs in pools.items():
        instruments = []
        for p in programs:
            name = "Drums (Channel 10)" if p == -1 else GM_PROGRAM_NAMES[p]
            instruments.append({"program": p, "name": name})
        track_types[track_type] = instruments
    return track_types


def _extract_genre_from_tags(tags: str | None) -> str | None:
    """Extract genre name from a tag string like 'jazz happy fast'."""
    if not tags:
        return None
    all_genres = set(GENRE_TAGS) | {g.lower() for g in DISCOVERED_GENRES}
    for word in tags.lower().split():
        if word in all_genres:
            return word
    return None
