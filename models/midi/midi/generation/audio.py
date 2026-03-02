import os
import tempfile
import logging

logger = logging.getLogger(__name__)


def midi_to_mp3(midi_path: str, mp3_path: str, soundfont_path: str = None):
    """
    Convert a MIDI file to MP3.

    Requires:
        - FluidSynth installed on the system (brew install fluidsynth)
        - ffmpeg installed for MP3 encoding (brew install ffmpeg)
        - A SoundFont file (.sf2)

    Args:
        midi_path: Path to input MIDI file
        mp3_path: Path for output MP3 file
        soundfont_path: Path to SoundFont file. If None, searches common locations.
    """
    import subprocess
    import shutil
    if not shutil.which("ffmpeg"):
        print("Error: ffmpeg not found. Install with: brew install ffmpeg")
        return False

    # Find a SoundFont if not provided
    if soundfont_path is None:
        soundfont_path = find_soundfont()

    if soundfont_path is None:
        print("Error: No SoundFont file found.")
        print("Please provide a SoundFont with --soundfont or install one:")
        print("  macOS: brew install fluid-synth (includes default SoundFont)")
        print("  Or download from: https://member.keymusician.com/Member/FluidR3_GM/")
        return False

    print(f"Using SoundFont: {soundfont_path}")

    # Convert MIDI to WAV using FluidSynth directly (midi2audio uses outdated syntax)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp_wav:
        wav_path = tmp_wav.name

    try:
        # Use fluidsynth directly (options must come before soundfont and midi files)
        cmd = [
            "fluidsynth",
            "-ni",           # No interactive mode, no shell
            "-F", wav_path,  # Output file
            "-r", "44100",   # Sample rate
            "-q",            # Quiet mode
            "-R", "0",       # Disable reverb
            "-C", "0",       # Disable chorus
            "-g", "1.0",     # Gain (adjust if too quiet)
            soundfont_path,
            midi_path,
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        if result.returncode != 0:
            print(f"FluidSynth error: {result.stderr}")
            return False

        # Convert WAV to MP3 using ffmpeg directly (avoids Python wave module's 4GB limit)
        result2 = subprocess.run(
            ["ffmpeg", "-y", "-i", wav_path, "-b:a", "192k", mp3_path],
            capture_output=True, text=True, timeout=120,
        )
        if result2.returncode != 0:
            print(f"ffmpeg error: {result2.stderr}")
            return False

        print(f"MP3 saved to: {mp3_path}")
        return True

    except Exception as e:
        print(f"Error converting to MP3: {e}")
        return False
    finally:
        # Clean up temporary WAV file
        if os.path.exists(wav_path):
            os.remove(wav_path)


def find_soundfont():
    """Search for a SoundFont file in common locations.

    Prefers full General MIDI SoundFonts (FluidR3_GM, GeneralUser, MuseScore)
    over the minimal VintageDreamsWaves that ships with Homebrew fluid-synth.
    """
    import glob

    # Priority order: full GM SoundFonts first, then local project files
    common_paths = [
        # Local project directory (user-provided, highest priority)
        "FluidR3_GM.sf2",
        "GeneralUser_GS.sf2",
        "soundfont.sf2",
        # macOS Homebrew locations
        "/opt/homebrew/share/soundfonts/FluidR3_GM.sf2",
        "/opt/homebrew/share/soundfonts/GeneralUser_GS.sf2",
        "/opt/homebrew/share/fluid-synth/FluidR3_GM.sf2",
        "/usr/local/share/soundfonts/FluidR3_GM.sf2",
        "/usr/local/share/fluid-synth/FluidR3_GM.sf2",
        # Linux locations
        "/usr/share/soundfonts/FluidR3_GM.sf2",
        "/usr/share/sounds/sf2/FluidR3_GM.sf2",
        "/usr/share/soundfonts/default.sf2",
        # MuseScore SoundFont (good quality, often installed)
        "/usr/share/mscore/sounds/MuseScore_General.sf2",
        "/opt/homebrew/share/mscore/sounds/MuseScore_General.sf2",
    ]

    for path in common_paths:
        if os.path.exists(path):
            return path

    # Check Homebrew Cellar location
    cellar_patterns = [
        "/opt/homebrew/Cellar/fluid-synth/*/share/fluid-synth/sf2/*.sf2",
        "/usr/local/Cellar/fluid-synth/*/share/fluid-synth/sf2/*.sf2",
    ]
    for pattern in cellar_patterns:
        matches = glob.glob(pattern)
        if matches:
            # Prefer full GM SoundFonts, skip VintageDreamsWaves (tiny/thin-sounding)
            good = [m for m in matches if "VintageDreams" not in m and all(ord(c) < 128 for c in m)]
            if good:
                return good[0]

    # Last resort: accept whatever Homebrew has (including VintageDreamsWaves)
    sf_dir = "/opt/homebrew/share/soundfonts"
    if os.path.isdir(sf_dir):
        for name in sorted(os.listdir(sf_dir)):
            if name.endswith(".sf2") and all(ord(c) < 128 for c in name):
                found = os.path.join(sf_dir, name)
                print(f"Warning: Using '{name}' — for better quality, download FluidR3_GM.sf2")
                return found

    return None
