import argparse
import uuid
import random
import torch
import logging
from pathlib import Path
from datetime import datetime

from ..tokenization import get_available_tags
from ..model import MultiTrackMusicTransformer
from .loader import load_model, load_multitrack_model
from .single_track import generate_music
from .multi_track import generate_multitrack_music, add_track_to_midi, replace_track_in_midi, cover_midi
from .audio import midi_to_mp3
from .instruments import gm_program_name

logger = logging.getLogger(__name__)


def main():
    # Setup logging
    log_dir = Path("logs")
    log_dir.mkdir(exist_ok=True)
    log_file = log_dir / f"generate_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(levelname)s - %(message)s",
        handlers=[
            logging.FileHandler(log_file),
            logging.StreamHandler(),
        ],
    )

    parser = argparse.ArgumentParser(description="Generate MIDI music")
    parser.add_argument(
        "--checkpoint",
        type=str,
        default="checkpoints/default",
        help="Path to model folder (containing checkpoint + tokenizer.json) or direct .pt file"
    )
    parser.add_argument(
        "--lora-adapter",
        type=str,
        default=None,
        help="Path to LoRA adapter file (trained with --lora)"
    )
    parser.add_argument(
        "--prompt",
        type=str,
        default=None,
        help="Optional MIDI file to use as prompt"
    )
    parser.add_argument(
        "--extend-from",
        type=float,
        default=None,
        help="Time position to extend from (requires --prompt). Positive=override after this time, negative=append (e.g., -30 uses last 30s as context)"
    )
    parser.add_argument(
        "--tags",
        type=str,
        default=None,
        help="Style tags like 'jazz happy fast' (genre/mood/tempo)"
    )
    parser.add_argument(
        "--output",
        type=str,
        default=None,
        help="Output MIDI file path (default: <uuid>.mid)"
    )
    parser.add_argument(
        "--duration",
        type=int,
        default=60,
        help="Duration in seconds (default: 60)"
    )
    parser.add_argument(
        "--bpm",
        type=int,
        default=120,
        help="Target tempo in BPM (default: 120)"
    )
    parser.add_argument(
        "--creativity",
        type=float,
        default=1.0,
        help="Creativity level (higher = more experimental, default: 1.0)"
    )
    parser.add_argument(
        "--exploration",
        type=float,
        default=None,
        help="Exploration level 0.0-1.0 (overrides --top-k and --top-p). 0.0=conservative, 1.0=adventurous"
    )
    parser.add_argument(
        "--top-k",
        type=int,
        default=50,
        help="Top-k sampling (0 to disable)"
    )
    parser.add_argument(
        "--top-p",
        type=float,
        default=0.95,
        help="Nucleus sampling threshold"
    )
    parser.add_argument(
        "--repetition-penalty",
        type=float,
        default=1.2,
        help="Penalize repeated tokens (1.0 = disabled, >1.0 = less repetition, default: 1.2)"
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=None,
        help="Random seed for reproducibility"
    )
    parser.add_argument(
        "--mp3",
        action="store_true",
        help="Also export as MP3 (requires FluidSynth and ffmpeg)"
    )
    parser.add_argument(
        "--soundfont",
        type=str,
        default=None,
        help="Path to SoundFont file (.sf2) for MP3 conversion"
    )

    # Multi-track options
    parser.add_argument(
        "--multitrack",
        action="store_true",
        help="Generate multi-track music (default: 4 tracks)"
    )
    parser.add_argument(
        "--num-tracks",
        type=int,
        default=None,
        help="Number of tracks (auto-detected from --track-types if provided)"
    )
    parser.add_argument(
        "--track-types",
        type=str,
        default=None,
        help="Comma-separated track types (enables multitrack): melody,bass,chords,drums,pad,lead,other"
    )
    parser.add_argument(
        "--instruments",
        type=str,
        default=None,
        help="Comma-separated MIDI program numbers (0=piano, 33=bass, -1=drums, etc.)"
    )
    parser.add_argument(
        "--add-track",
        type=str,
        default=None,
        metavar="TYPE",
        help="Add a track to an existing MIDI file (requires --prompt). "
             "TYPE is the track role: melody, bass, chords, drums, pad, lead, strings, other"
    )
    parser.add_argument(
        "--replace-track",
        type=int,
        default=None,
        metavar="N",
        help="Replace track N in existing MIDI (1-based, requires --prompt). "
             "Use --track-types and --instruments to change type/instrument"
    )
    parser.add_argument(
        "--replace-bars",
        type=str,
        default=None,
        metavar="RANGE",
        help="Bar range to replace within --replace-track (1-based). "
             "Examples: '8' or '8-' (from bar 8 to end), '8-16' (bars 8 through 16)"
    )
    parser.add_argument(
        "--cover",
        action="store_true",
        help="Generate a cover of an existing MIDI file (requires --prompt). "
             "Uses the reference as frozen context via cross-track attention, "
             "then outputs only the newly generated tracks"
    )
    parser.add_argument(
        "--humanize",
        type=str,
        default=None,
        choices=["light", "medium", "heavy"],
        help="Post-process MIDI with humanization (light/medium/heavy)"
    )
    parser.add_argument(
        "--half",
        action="store_true",
        help="Use float16 for inference (faster on GPU/MPS, halves memory)"
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Enable DEBUG-level logging (model shapes, sampling stats, cache events)"
    )

    args = parser.parse_args()

    # Validate --add-track requires --prompt
    if args.add_track and not args.prompt:
        parser.error("--add-track requires --prompt to specify the existing MIDI file")

    # Validate --replace-track requires --prompt
    if args.replace_track is not None and not args.prompt:
        parser.error("--replace-track requires --prompt to specify the existing MIDI file")

    # Validate --cover requires --prompt
    if args.cover and not args.prompt:
        parser.error("--cover requires --prompt to specify the reference MIDI file")

    # Validate --replace-bars requires --replace-track
    if args.replace_bars is not None and args.replace_track is None:
        parser.error("--replace-bars requires --replace-track")

    # Set log level based on --debug flag
    if args.debug:
        logging.getLogger().setLevel(logging.DEBUG)
        logging.getLogger("midi").setLevel(logging.DEBUG)

    # Map --exploration to top-k and top-p
    if args.exploration is not None:
        e = max(0.0, min(1.0, args.exploration))
        args.top_k = int(5 + e * 195)     # 5 -> 200
        args.top_p = 0.7 + e * 0.3        # 0.7 -> 1.0
        print(f"Exploration {e:.2f} -> top_k={args.top_k}, top_p={args.top_p:.2f}")

    # Set seed if provided
    if args.seed is not None:
        torch.manual_seed(args.seed)
        print(f"Using random seed: {args.seed}")

    # Setup
    def get_device():
        if torch.cuda.is_available():
            return torch.device("cuda")
        elif torch.backends.mps.is_available():
            return torch.device("mps")
        return torch.device("cpu")

    device = get_device()
    print(f"Using device: {device}")

    # Resolve checkpoint path: supports both a directory (model folder)
    # and a direct path to a .pt file.
    checkpoint_input = Path(args.checkpoint)
    if checkpoint_input.is_dir():
        model_dir = checkpoint_input
        # Find best checkpoint in directory
        best = model_dir / "best_model.pt"
        epoch_ckpts = sorted(
            model_dir.glob("checkpoint_epoch_*.pt"),
            key=lambda p: int(p.stem.split("_")[-1]),
        )
        if best.exists():
            checkpoint_file = best
        elif epoch_ckpts:
            checkpoint_file = epoch_ckpts[-1]
        else:
            pt_files = list(model_dir.glob("*.pt"))
            if len(pt_files) == 1:
                checkpoint_file = pt_files[0]
            else:
                print(f"Error: No checkpoint (.pt) found in {model_dir}")
                return
    elif checkpoint_input.is_file():
        checkpoint_file = checkpoint_input
        model_dir = checkpoint_input.parent
    else:
        print(f"Error: Checkpoint not found at {args.checkpoint}")
        print("Please train a model first using train.py")
        return

    # Load model
    print(f"Loading model from {checkpoint_file}")
    lora_adapter = getattr(args, 'lora_adapter', None)
    if lora_adapter:
        print(f"Loading LoRA adapter from {lora_adapter}")
    dtype = torch.float16 if args.half else None
    model = load_model(str(checkpoint_file), device, lora_adapter_path=lora_adapter, dtype=dtype)

    # Load tokenizer from the same model folder (required)
    tokenizer_path = model_dir / "tokenizer.json"
    if not tokenizer_path.exists():
        print(f"Error: No tokenizer.json found in {model_dir}")
        print("Each model folder must contain its compatible tokenizer.")
        print("The tokenizer is saved during training/pretokenization.")
        return
    from miditok import REMI
    tokenizer = REMI(params=tokenizer_path)
    print(f"Loaded tokenizer from {tokenizer_path}")

    # Show available tags if requested
    if args.tags == "list":
        print("\nAvailable tags:")
        for category, tags in get_available_tags(tokenizer).items():
            print(f"  {category}: {', '.join(tags)}")
        return

    # Parse track types and instruments early (may enable multitrack)
    track_types = None
    if args.track_types:
        track_types = [t.strip().lower() for t in args.track_types.split(",")]

    instruments = None
    if args.instruments:
        instruments = [int(i.strip()) for i in args.instruments.split(",")]

    # Enable multitrack if --track-types is provided or model is multitrack
    use_multitrack = args.multitrack or track_types is not None or isinstance(model, MultiTrackMusicTransformer)

    # Determine number of tracks
    if args.num_tracks is not None:
        num_tracks = args.num_tracks
    elif track_types is not None:
        num_tracks = len(track_types)
    else:
        num_tracks = random.randint(3, 8)

    # Generate output filename if not specified
    if args.output is None:
        args.output = f"{uuid.uuid4()}.mid"

    # Convert duration (seconds) to tokens (scales with BPM)
    # REMI uses ~4 tokens per note + bar markers ≈ 30 tokens/second at 120 BPM
    tokens_per_second = 30 * (args.bpm / 120.0)
    num_tokens = int(args.duration * tokens_per_second)

    # Generate
    if args.cover:
        # Cover mode: generate new tracks conditioned on reference MIDI
        print(f"Covering {args.prompt}")

        # Ensure we have a multitrack model
        if not isinstance(model, MultiTrackMusicTransformer):
            model = load_multitrack_model(args.checkpoint, device, lora_adapter_path=lora_adapter, dtype=dtype)

        midi_path = cover_midi(
            model=model,
            tokenizer=tokenizer,
            device=device,
            midi_path=args.prompt,
            num_tracks=args.num_tracks,
            track_types=track_types,
            instruments=instruments,
            tags=args.tags,
            num_tokens_per_track=num_tokens,
            temperature=args.creativity,
            top_k=args.top_k,
            top_p=args.top_p,
            repetition_penalty=args.repetition_penalty,
            output_path=args.output,
        )
    elif args.replace_track is not None:
        # Replace-track mode: replace a track (or bars within a track)
        track_idx = args.replace_track - 1  # Convert 1-based to 0-based

        # Ensure we have a multitrack model
        if not isinstance(model, MultiTrackMusicTransformer):
            model = load_multitrack_model(args.checkpoint, device, lora_adapter_path=lora_adapter, dtype=dtype)

        # Parse --replace-bars if provided
        replace_bars = None
        if args.replace_bars:
            bars_str = args.replace_bars.rstrip("-")
            parts = bars_str.split("-")
            if len(parts) == 1:
                # "8" or "8-" -> from bar 8 to end
                replace_bars = (int(parts[0]) - 1,)  # 1-based to 0-based
            else:
                # "8-16" -> bars 8 through 16
                replace_bars = (int(parts[0]) - 1, int(parts[1]) - 1)

        # Use first values from --track-types/--instruments if provided
        replace_type = track_types[0] if track_types else None
        replace_instrument = instruments[0] if instruments else None

        midi_path = replace_track_in_midi(
            model=model,
            tokenizer=tokenizer,
            device=device,
            midi_path=args.prompt,
            track_index=track_idx,
            track_type=replace_type,
            instrument=replace_instrument,
            replace_bars=replace_bars,
            tags=args.tags,
            num_tokens_per_track=num_tokens,
            temperature=args.creativity,
            top_k=args.top_k,
            top_p=args.top_p,
            repetition_penalty=args.repetition_penalty,
            output_path=args.output,
        )
    elif args.add_track:
        # Add-track mode: add a single track to an existing MIDI
        print(f"Adding {args.add_track} track to {args.prompt}")

        # Ensure we have a multitrack model
        if not isinstance(model, MultiTrackMusicTransformer):
            model = load_multitrack_model(args.checkpoint, device, lora_adapter_path=lora_adapter, dtype=dtype)

        # Use first instrument from --instruments if provided
        add_instrument = instruments[0] if instruments else None

        midi_path = add_track_to_midi(
            model=model,
            tokenizer=tokenizer,
            device=device,
            midi_path=args.prompt,
            track_type=args.add_track.lower(),
            instrument=add_instrument,
            tags=args.tags,
            num_tokens_per_track=num_tokens,
            temperature=args.creativity,
            top_k=args.top_k,
            top_p=args.top_p,
            repetition_penalty=args.repetition_penalty,
            output_path=args.output,
        )
    elif use_multitrack:
        # Multi-track generation
        print(f"Using multi-track generation mode ({num_tracks} tracks)")

        # Reload as multitrack only if load_model() returned a single-track model
        if not isinstance(model, MultiTrackMusicTransformer):
            model = load_multitrack_model(args.checkpoint, device, lora_adapter_path=lora_adapter, dtype=dtype)

        midi_path = generate_multitrack_music(
            model=model,
            tokenizer=tokenizer,
            device=device,
            num_tracks=num_tracks,
            track_types=track_types,
            instruments=instruments,
            tags=args.tags,
            num_tokens_per_track=num_tokens,
            temperature=args.creativity,
            top_k=args.top_k,
            top_p=args.top_p,
            repetition_penalty=args.repetition_penalty,
            output_path=args.output,
        )
    else:
        # Single-track generation (original behavior)
        midi_path = generate_music(
            model=model,
            tokenizer=tokenizer,
            device=device,
            prompt_path=args.prompt,
            extend_from=args.extend_from,
            tags=args.tags,
            num_tokens=num_tokens,
            temperature=args.creativity,
            top_k=args.top_k,
            top_p=args.top_p,
            repetition_penalty=args.repetition_penalty,
            output_path=args.output,
        )

    # Apply humanization post-processing
    if args.humanize and midi_path:
        from ..tokenization.midi_io import humanize_midi
        from symusic import Score
        HUMANIZE_PRESETS = {
            "light": dict(
                timing_jitter_ms=10, velocity_jitter=5,
                duration_variance=0.03, beat_accent=5,
                legato_overlap=1.02, phrase_dynamics=0.06, swing_amount=0.0,
            ),
            "medium": dict(
                timing_jitter_ms=18, velocity_jitter=10,
                duration_variance=0.05, beat_accent=10,
                legato_overlap=1.05, phrase_dynamics=0.12, swing_amount=0.05,
            ),
            "heavy": dict(
                timing_jitter_ms=25, velocity_jitter=15,
                duration_variance=0.08, beat_accent=14,
                legato_overlap=1.08, phrase_dynamics=0.18, swing_amount=0.12,
            ),
        }
        preset = HUMANIZE_PRESETS[args.humanize]
        score = Score(midi_path)
        score = humanize_midi(score, **preset)
        score.dump_midi(midi_path)
        print(f"Applied '{args.humanize}' humanization")

    # Convert to MP3 if requested
    if args.mp3 and midi_path:
        mp3_path = str(Path(midi_path).with_suffix(".mp3"))
        midi_to_mp3(midi_path, mp3_path, args.soundfont)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        logger.exception(f"Generation failed with error: {e}")
        raise
