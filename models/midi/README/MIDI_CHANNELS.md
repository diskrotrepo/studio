# MIDI Channels Reference

MIDI supports 16 channels numbered 1-16. Each channel carries independent note, control, and program data. Channel 10 is reserved for percussion.

## Channel Assignments

| Channel | Standard Role | Notes |
|---------|--------------|-------|
| 1 | Melody / Lead | Primary melodic voice |
| 2 | Harmony / Chords | Pads, comping, rhythm guitar |
| 3 | Countermelody | Secondary melodic line |
| 4 | Bass | Bass guitar, synth bass, upright bass |
| 5 | Strings | String ensemble, solo strings |
| 6 | Brass | Trumpet, trombone, horn section |
| 7 | Woodwinds | Flute, clarinet, saxophone |
| 8 | Synth Lead | Synth melody, arpeggiated lines |
| 9 | Synth Pad | Atmospheric pads, textures |
| 10 | **Percussion** | **Drums and percussion (fixed by MIDI spec)** |
| 11 | Auxiliary Percussion | Secondary percussion, shaker, tambourine |
| 12 | Effects | Sound effects, risers, impacts |
| 13 | Accompaniment | Additional harmonic support |
| 14 | Orchestral | Orchestral layers |
| 15 | Auxiliary | Overflow or additional parts |
| 16 | Auxiliary | Overflow or additional parts |

## Channel 10 Percussion Map (General MIDI)

Key numbers map to specific percussion instruments on channel 10:

| Key | Instrument | Key | Instrument |
|-----|-----------|-----|-----------|
| 35 | Acoustic Bass Drum | 51 | Ride Cymbal 1 |
| 36 | Bass Drum 1 | 52 | Chinese Cymbal |
| 37 | Side Stick | 53 | Ride Bell |
| 38 | Acoustic Snare | 54 | Tambourine |
| 39 | Hand Clap | 55 | Splash Cymbal |
| 40 | Electric Snare | 56 | Cowbell |
| 41 | Low Floor Tom | 57 | Crash Cymbal 2 |
| 42 | Closed Hi-Hat | 58 | Vibraslap |
| 43 | High Floor Tom | 59 | Ride Cymbal 2 |
| 44 | Pedal Hi-Hat | 60 | Hi Bongo |
| 45 | Low Tom | 61 | Low Bongo |
| 46 | Open Hi-Hat | 62 | Mute Hi Conga |
| 47 | Low-Mid Tom | 63 | Open Hi Conga |
| 48 | Hi-Mid Tom | 64 | Low Conga |
| 49 | Crash Cymbal 1 | 65 | High Timbale |
| 50 | High Tom | 66 | Low Timbale |
| 67 | High Agogo | 73 | Short Guiro |
| 68 | Low Agogo | 74 | Long Guiro |
| 69 | Cabasa | 75 | Claves |
| 70 | Maracas | 76 | Hi Wood Block |
| 71 | Short Whistle | 77 | Low Wood Block |
| 72 | Long Whistle | 78 | Mute Cuica |
| 79 | Open Cuica | 80 | Mute Triangle |
| 81 | Open Triangle | | |

## General MIDI Program Numbers (0-127)

Instruments assigned per-channel via Program Change messages.

### Piano (0-7)
0 Acoustic Grand Piano, 1 Bright Acoustic Piano, 2 Electric Grand Piano, 3 Honky-tonk Piano, 4 Electric Piano 1, 5 Electric Piano 2, 6 Harpsichord, 7 Clavinet

### Chromatic Percussion (8-15)
8 Celesta, 9 Glockenspiel, 10 Music Box, 11 Vibraphone, 12 Marimba, 13 Xylophone, 14 Tubular Bells, 15 Dulcimer

### Organ (16-23)
16 Drawbar Organ, 17 Percussive Organ, 18 Rock Organ, 19 Church Organ, 20 Reed Organ, 21 Accordion, 22 Harmonica, 23 Tango Accordion

### Guitar (24-31)
24 Acoustic Guitar (nylon), 25 Acoustic Guitar (steel), 26 Electric Guitar (jazz), 27 Electric Guitar (clean), 28 Electric Guitar (muted), 29 Overdriven Guitar, 30 Distortion Guitar, 31 Guitar Harmonics

### Bass (32-39)
32 Acoustic Bass, 33 Electric Bass (finger), 34 Electric Bass (pick), 35 Fretless Bass, 36 Slap Bass 1, 37 Slap Bass 2, 38 Synth Bass 1, 39 Synth Bass 2

### Strings (40-47)
40 Violin, 41 Viola, 42 Cello, 43 Contrabass, 44 Tremolo Strings, 45 Pizzicato Strings, 46 Orchestral Harp, 47 Timpani

### Ensemble (48-55)
48 String Ensemble 1, 49 String Ensemble 2, 50 Synth Strings 1, 51 Synth Strings 2, 52 Choir Aahs, 53 Voice Oohs, 54 Synth Choir, 55 Orchestra Hit

### Brass (56-63)
56 Trumpet, 57 Trombone, 58 Tuba, 59 Muted Trumpet, 60 French Horn, 61 Brass Section, 62 Synth Brass 1, 63 Synth Brass 2

### Reed (64-71)
64 Soprano Sax, 65 Alto Sax, 66 Tenor Sax, 67 Baritone Sax, 68 Oboe, 69 English Horn, 70 Bassoon, 71 Clarinet

### Pipe (72-79)
72 Piccolo, 73 Flute, 74 Recorder, 75 Pan Flute, 76 Blown Bottle, 77 Shakuhachi, 78 Whistle, 79 Ocarina

### Synth Lead (80-87)
80 Lead 1 (square), 81 Lead 2 (sawtooth), 82 Lead 3 (calliope), 83 Lead 4 (chiff), 84 Lead 5 (charang), 85 Lead 6 (voice), 86 Lead 7 (fifths), 87 Lead 8 (bass + lead)

### Synth Pad (88-95)
88 Pad 1 (new age), 89 Pad 2 (warm), 90 Pad 3 (polysynth), 91 Pad 4 (choir), 92 Pad 5 (bowed), 93 Pad 6 (metallic), 94 Pad 7 (halo), 95 Pad 8 (sweep)

### Synth Effects (96-103)
96 FX 1 (rain), 97 FX 2 (soundtrack), 98 FX 3 (crystal), 99 FX 4 (atmosphere), 100 FX 5 (brightness), 101 FX 6 (goblins), 102 FX 7 (echoes), 103 FX 8 (sci-fi)

### Ethnic (104-111)
104 Sitar, 105 Banjo, 106 Shamisen, 107 Koto, 108 Kalimba, 109 Bagpipe, 110 Fiddle, 111 Shanai

### Percussive (112-119)
112 Tinkle Bell, 113 Agogo, 114 Steel Drums, 115 Woodblock, 116 Taiko Drum, 117 Melodic Tom, 118 Synth Drum, 119 Reverse Cymbal

### Sound Effects (120-127)
120 Guitar Fret Noise, 121 Breath Noise, 122 Seashore, 123 Bird Tweet, 124 Telephone Ring, 125 Helicopter, 126 Applause, 127 Gunshot

## Key MIDI Concepts

### Velocity
Note loudness from 0-127. Velocity 0 is equivalent to Note Off.

### Control Change (CC) Messages
| CC | Function |
|----|----------|
| 1 | Modulation Wheel |
| 7 | Channel Volume |
| 10 | Pan |
| 11 | Expression |
| 64 | Sustain Pedal (on/off at 64) |
| 91 | Reverb Send |
| 93 | Chorus Send |
| 121 | Reset All Controllers |
| 123 | All Notes Off |

### Note Range
MIDI notes span 0-127 (C-1 to G9). Middle C is note 60 (C4).

| Octave | C | C#/Db | D | D#/Eb | E | F | F#/Gb | G | G#/Ab | A | A#/Bb | B |
|--------|---|-------|---|-------|---|---|-------|---|-------|---|-------|---|
| -1 | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 |
| 0 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 | 21 | 22 | 23 |
| 1 | 24 | 25 | 26 | 27 | 28 | 29 | 30 | 31 | 32 | 33 | 34 | 35 |
| 2 | 36 | 37 | 38 | 39 | 40 | 41 | 42 | 43 | 44 | 45 | 46 | 47 |
| 3 | 48 | 49 | 50 | 51 | 52 | 53 | 54 | 55 | 56 | 57 | 58 | 59 |
| 4 | 60 | 61 | 62 | 63 | 64 | 65 | 66 | 67 | 68 | 69 | 70 | 71 |
| 5 | 72 | 73 | 74 | 75 | 76 | 77 | 78 | 79 | 80 | 81 | 82 | 83 |
| 6 | 84 | 85 | 86 | 87 | 88 | 89 | 90 | 91 | 92 | 93 | 94 | 95 |
| 7 | 96 | 97 | 98 | 99 | 100 | 101 | 102 | 103 | 104 | 105 | 106 | 107 |
| 8 | 108 | 109 | 110 | 111 | 112 | 113 | 114 | 115 | 116 | 117 | 118 | 119 |
| 9 | 120 | 121 | 122 | 123 | 124 | 125 | 126 | 127 | | | | |

## Generation Examples

Use `--instruments` to specify MIDI program numbers and `--track-types` to assign roles. Drums always use program `-1`.

### Rock Band

```bash
python3 generate.py --multitrack \
  --track-types "melody,chords,bass,drums" \
  --instruments "29,27,34,-1" \
  --mp3 \
  --tags "rock energetic loud"
```

| Track | Type | Program | Instrument |
|-------|------|---------|------------|
| 1 | melody | 29 | Overdriven Guitar |
| 2 | chords | 27 | Electric Guitar (clean) |
| 3 | bass | 34 | Electric Bass (pick) |
| 4 | drums | -1 | Percussion (channel 10) |

### Jazz Combo

```bash
python3 generate.py --multitrack \
  --track-types "melody,chords,bass,drums" \
  --instruments "66,0,32,-1" \
  --mp3 \
  --tags "jazz swing expressive"
```

| Track | Type | Program | Instrument |
|-------|------|---------|------------|
| 1 | melody | 66 | Tenor Sax |
| 2 | chords | 0 | Acoustic Grand Piano |
| 3 | bass | 32 | Acoustic Bass |
| 4 | drums | -1 | Percussion (channel 10) |

### Orchestral Arrangement

```bash
python3 generate.py --multitrack \
  --track-types "melody,strings,brass,woodwind,bass,drums" \
  --instruments "40,48,61,73,43,-1" \
  --mp3 \
  --tags "classical complex_harmony full_arrangement legato" \
  --num-tracks 6
```

| Track | Type | Program | Instrument |
|-------|------|---------|------------|
| 1 | melody | 40 | Violin |
| 2 | strings | 48 | String Ensemble 1 |
| 3 | brass | 61 | Brass Section |
| 4 | woodwind | 73 | Flute |
| 5 | bass | 43 | Contrabass |
| 6 | drums | -1 | Percussion (Timpani via channel 10) |

### Electronic / Synth

```bash
python3 generate.py --multitrack \
  --track-types "lead,pad,bass,drums,chords" \
  --instruments "81,89,38,-1,91" \
  --mp3 \
  --tags "electronic dark dense syncopated"
```

| Track | Type | Program | Instrument |
|-------|------|---------|------------|
| 1 | lead | 81 | Lead 2 (sawtooth) |
| 2 | pad | 89 | Pad 2 (warm) |
| 3 | bass | 38 | Synth Bass 1 |
| 4 | drums | -1 | Percussion (channel 10) |
| 5 | chords | 91 | Pad 4 (choir) |

### Ambient / Cinematic

```bash
python3 generate.py --multitrack \
  --track-types "pad,strings,melody,fx" \
  --instruments "95,50,79,99" \
  --tags "ambient calm sparse legato slow" \
  --mp3 \
  --creativity 1.3
```

| Track | Type | Program | Instrument |
|-------|------|---------|------------|
| 1 | pad | 95 | Pad 8 (sweep) |
| 2 | strings | 50 | Synth Strings 1 |
| 3 | melody | 79 | Ocarina |
| 4 | fx | 99 | FX 4 (atmosphere) |

### Latin / World

```bash
python3 generate.py --multitrack \
  --track-types "melody,chords,bass,drums,other" \
  --instruments "24,22,32,-1,104" \
  --mp3 \
  --tags "latin energetic syncopated"
```

| Track | Type | Program | Instrument |
|-------|------|---------|------------|
| 1 | melody | 24 | Acoustic Guitar (nylon) |
| 2 | chords | 22 | Harmonica |
| 3 | bass | 32 | Acoustic Bass |
| 4 | drums | -1 | Percussion (channel 10) |
| 5 | other | 104 | Sitar |

### Solo Piano

```bash
python3 generate.py --tags "classical calm legato solo minor" --creativity 0.9
```

Single-track mode. Model generates one piano voice with full conditioning tags.

### Quick Reference: Common Instrument Picks by Genre

| Genre | Melody | Chords | Bass | Extra |
|-------|--------|--------|------|-------|
| Rock | 29 Overdriven Guitar | 27 Clean Guitar | 34 Bass (pick) | 30 Distortion Guitar |
| Jazz | 66 Tenor Sax | 0 Piano | 32 Acoustic Bass | 56 Trumpet |
| Classical | 40 Violin | 48 String Ensemble | 43 Contrabass | 73 Flute |
| Electronic | 81 Sawtooth Lead | 89 Warm Pad | 38 Synth Bass 1 | 80 Square Lead |
| Funk | 27 Clean Guitar | 4 Electric Piano 1 | 36 Slap Bass 1 | 16 Drawbar Organ |
| Country | 25 Steel Guitar | 24 Nylon Guitar | 33 Bass (finger) | 105 Banjo |
| R&B/Soul | 4 Electric Piano 1 | 89 Warm Pad | 33 Bass (finger) | 52 Choir Aahs |
| Metal | 30 Distortion Guitar | 29 Overdriven Guitar | 34 Bass (pick) | 30 Distortion Guitar |
| Ambient | 88 New Age Pad | 95 Sweep Pad | 38 Synth Bass 1 | 99 Atmosphere FX |
| Latin | 24 Nylon Guitar | 22 Harmonica | 32 Acoustic Bass | 114 Steel Drums |
