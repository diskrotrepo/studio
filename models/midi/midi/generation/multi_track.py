import random
import torch
import logging

from ..model import MultiTrackMusicTransformer
from ..tokenization import parse_tags, tokenize_multitrack_midi, tokens_to_multitrack_midi
from ..model.multitrack_utils import compute_track_ids
from .instruments import (
    gm_program_name, _extract_genre_from_tags,
    GENRE_TRACK_DEFAULTS, GENRE_INSTRUMENT_POOLS, GENERIC_INSTRUMENT_POOLS,
)

logger = logging.getLogger(__name__)


def generate_multitrack_music(
    model: MultiTrackMusicTransformer,
    tokenizer,
    device: torch.device,
    num_tracks: int = 4,
    track_types: list = None,
    instruments: list = None,
    tags: str = None,
    num_tokens_per_track: int = 256,
    temperature: float = 1.0,
    top_k: int = 50,
    top_p: float = 0.95,
    repetition_penalty: float = 1.2,
    output_path: str = "generated_multitrack.mid",
    progress_callback=None,
):
    """
    Generate multi-track music.

    Generates tracks sequentially, with each track conditioned on previous tracks.
    When tags include a genre (e.g. "jazz"), track types and instruments are
    automatically selected to match that genre's conventions.

    Args:
        model: Multi-track model
        tokenizer: MIDI tokenizer
        device: Device to run on
        num_tracks: Number of tracks to generate
        track_types: List of track types (e.g., ["melody", "bass", "chords", "drums"]).
                    If None, chosen based on genre tag or generic defaults.
        instruments: List of MIDI program numbers for each track.
                    If None, chosen from genre-appropriate pools.
        tags: Style tags like "jazz happy fast"
        num_tokens_per_track: Tokens to generate per track
        temperature: Sampling temperature
        top_k: Top-k sampling parameter
        top_p: Nucleus sampling parameter
        repetition_penalty: Penalize repeated tokens (1.0 = disabled, >1.0 = less repetition)
        output_path: Where to save the generated MIDI

    Returns:
        Path to generated MIDI file
    """
    try:
        logger.info(f"Starting multitrack generation: {num_tracks} tracks, output={output_path}")

        # Detect genre from tags for genre-aware defaults
        genre = _extract_genre_from_tags(tags)

        # Default track types: use genre-aware layout if available
        if track_types is None:
            if genre and genre in GENRE_TRACK_DEFAULTS:
                track_types = list(GENRE_TRACK_DEFAULTS[genre])[:num_tracks]
            else:
                base = ["melody", "bass"]
                extras = ["chords", "drums", "strings", "pad", "lead"]
                random.shuffle(extras)
                track_types = (base + extras)[:num_tracks]
                random.shuffle(track_types)

        # Default instruments: use genre-aware pools if available
        if instruments is None:
            pool = GENRE_INSTRUMENT_POOLS.get(genre, GENERIC_INSTRUMENT_POOLS)
            instruments = [random.choice(pool.get(t, [0])) for t in track_types]

        # Extend if needed
        while len(track_types) < num_tracks:
            track_types.append("other")
        while len(instruments) < num_tracks:
            instruments.append(0)

        track_summary = ", ".join(f"{t} ({gm_program_name(i)})" for t, i in zip(track_types, instruments))
        print(f"Generating {num_tracks} tracks: {track_summary}")

        # Parse tags
        tag_tokens = []
        if tags:
            tag_tokens = parse_tags(tags, tokenizer)
            if tag_tokens:
                print(f"Using tags: {tags}")

        # Suppress EOS to prevent premature sequence termination mid-track
        eos_suppress = []
        for name in ["EOS", "EOS_None"]:
            tid = tokenizer.vocab.get(name)
            if tid is not None:
                eos_suppress.append(tid)

        # Let TRACK_END be generated naturally so the model decides track length
        track_stop_tokens = []
        for name in ["TRACK_END"]:
            tid = tokenizer.vocab.get(name)
            if tid is not None:
                track_stop_tokens.append(tid)

        # Build initial prompt
        all_tokens = tag_tokens.copy()

        # Add BOS
        bos_id = tokenizer.vocab.get("BOS_None", tokenizer.vocab.get("BOS"))
        if bos_id is not None:
            all_tokens.append(bos_id)

        # Get special token IDs
        track_start_id = tokenizer.vocab.get("TRACK_START")
        track_end_id = tokenizer.vocab.get("TRACK_END")

        # Number of prefix tokens (tags + BOS) to preserve during sliding window
        n_prefix = len(all_tokens)

        # Track IDs for the prompt so far
        all_track_ids = [-1] * len(all_tokens)  # Tags and BOS are not in a track

        amp_dtype = torch.float16 if device.type == "mps" else torch.bfloat16
        amp_enabled = device.type in ("cuda", "mps")

        if progress_callback:
            progress_callback(0.0, 'Preparing generation...')

        # Generate each track sequentially
        for track_idx in range(num_tracks):
            track_type = track_types[track_idx]
            instrument = instruments[track_idx]

            print(f"\nGenerating track {track_idx + 1}/{num_tracks}: {track_type} (program {instrument} - {gm_program_name(instrument)})")

            # Add track start tokens
            track_header = []

            if track_start_id is not None:
                track_header.append(track_start_id)

            # Always add program token to match training sequence order
            # (training data is: TRACK_START -> Program_X -> TRACKTYPE_X -> music)
            program_token = f"Program_{instrument}"
            if program_token in tokenizer.vocab:
                track_header.append(tokenizer.vocab[program_token])

            # Add track type token
            track_type_token = f"TRACKTYPE_{track_type.upper()}"
            if track_type_token in tokenizer.vocab:
                track_header.append(tokenizer.vocab[track_type_token])

            # Add header to tokens
            all_tokens.extend(track_header)
            all_track_ids.extend([track_idx] * len(track_header))

            # Create prompt tensor
            prompt = torch.tensor([all_tokens], dtype=torch.long, device=device)
            track_ids_tensor = torch.tensor([all_track_ids], dtype=torch.long, device=device)

            # Progress callback for per-token updates within this track
            def _on_token_progress(step, total, _tidx=track_idx):
                if progress_callback:
                    # Each track gets an equal slice of 5%-90%
                    track_frac = (step / total) if total > 0 else 1.0
                    base = 0.05 + (_tidx / num_tracks) * 0.85
                    progress_callback(
                        base + track_frac * (0.85 / num_tracks),
                        f'Generating track {_tidx + 1}/{num_tracks} ({track_types[_tidx]})',
                    )

            if progress_callback:
                progress_callback(
                    0.05 + (track_idx / num_tracks) * 0.85,
                    f'Generating track {track_idx + 1}/{num_tracks} ({track_type})...',
                )

            # Generate tokens for this track
            # TRACK_END is a stop token -- the model decides when to end the track
            with torch.autocast(device_type=device.type, dtype=amp_dtype, enabled=amp_enabled):
                output = model.generate(
                    prompt,
                    track_ids=track_ids_tensor,
                    max_new_tokens=num_tokens_per_track,
                    temperature=temperature,
                    top_k=top_k,
                    top_p=top_p,
                    vocab_size=len(tokenizer.vocab),
                    track_id_for_new_tokens=track_idx,
                    suppress_tokens=eos_suppress,
                    stop_tokens=track_stop_tokens,
                    repetition_penalty=repetition_penalty,
                    n_prefix_tokens=n_prefix,
                    vocab=tokenizer.vocab,
                    on_progress=_on_token_progress,
                )

            # Extract newly generated tokens
            new_tokens = output[0].tolist()[len(all_tokens):]

            # Validate token bounds
            vocab_size = len(tokenizer.vocab)
            oob_tokens = [t for t in new_tokens if t < 0 or t >= vocab_size]
            if oob_tokens:
                logger.warning(
                    f"Track {track_idx + 1} generated {len(oob_tokens)} out-of-bounds tokens: "
                    f"{oob_tokens[:10]}"
                )

            # Add generated tokens (includes TRACK_END if model emitted it)
            all_tokens.extend(new_tokens)
            all_track_ids.extend([track_idx] * len(new_tokens))

            # If model didn't emit TRACK_END (hit max_new_tokens), add it
            if not new_tokens or new_tokens[-1] != track_end_id:
                if track_end_id is not None:
                    all_tokens.append(track_end_id)
                    all_track_ids.append(track_idx)

            track_content = [t for t in new_tokens if t != track_end_id]
            print(f"  Generated {len(track_content)} tokens for track {track_idx + 1}")

        # Add EOS
        eos_id = tokenizer.vocab.get("EOS_None", tokenizer.vocab.get("EOS"))
        if eos_id is not None:
            all_tokens.append(eos_id)

        print(f"\nTotal: {len(all_tokens)} tokens")

        # Check marker balance
        if track_start_id is not None and track_end_id is not None:
            starts = all_tokens.count(track_start_id)
            ends = all_tokens.count(track_end_id)
            if starts != ends:
                logger.warning(
                    f"Marker imbalance: {starts} TRACK_START vs {ends} TRACK_END"
                )

        if progress_callback:
            progress_callback(0.90, 'Converting to MIDI...')

        # Convert to MIDI
        tokens_to_multitrack_midi(tokenizer, all_tokens, output_path)
        print(f"Generated music saved to: {output_path}")
        logger.info(f"Multitrack generation complete: {len(all_tokens)} tokens, saved to {output_path}")

        return output_path
    except Exception as e:
        logger.exception(f"Multitrack generation failed: {e}")
        raise


def add_track_to_midi(
    model: MultiTrackMusicTransformer,
    tokenizer,
    device: torch.device,
    midi_path: str,
    track_type: str = "melody",
    instrument: int = None,
    tags: str = None,
    num_tokens_per_track: int = 256,
    temperature: float = 1.0,
    top_k: int = 50,
    top_p: float = 0.95,
    repetition_penalty: float = 1.2,
    output_path: str = "generated_multitrack.mid",
    progress_callback=None,
) -> str:
    """
    Add a new track to an existing MIDI file.

    Tokenizes the existing MIDI (preserving track structure), then generates
    a single new track conditioned on the existing tracks via cross-track attention.

    Args:
        model: Multi-track model
        tokenizer: MIDI tokenizer
        device: Device to run on
        midi_path: Path to existing MIDI file
        track_type: Role for the new track (melody, bass, chords, drums, etc.)
        instrument: MIDI program number for the new track (None = auto-select)
        tags: Optional style tags like "jazz happy fast"
        num_tokens_per_track: Tokens to generate for the new track
        temperature: Sampling temperature
        top_k: Top-k sampling parameter
        top_p: Nucleus sampling parameter
        repetition_penalty: Penalize repeated tokens (1.0 = disabled, >1.0 = less repetition)
        output_path: Where to save the output MIDI

    Returns:
        Path to output MIDI file
    """
    try:
        logger.info(f"Adding {track_type} track to {midi_path}, output={output_path}")

        # Tokenize existing MIDI (use_tags=False since this is a generated file,
        # not from a training dataset with folder-based tag inference)
        from pathlib import Path as _Path
        all_tokens, track_infos = tokenize_multitrack_midi(
            tokenizer, _Path(midi_path), use_tags=False
        )
        num_existing_tracks = len(track_infos)
        print(f"Loaded {midi_path}: {num_existing_tracks} existing tracks, {len(all_tokens)} tokens")

        # Optionally prepend user-specified tags before BOS
        if tags:
            tag_tokens = parse_tags(tags, tokenizer)
            if tag_tokens:
                bos_id = tokenizer.vocab.get("BOS_None", tokenizer.vocab.get("BOS"))
                if bos_id is not None and bos_id in all_tokens:
                    bos_pos = all_tokens.index(bos_id)
                    all_tokens = all_tokens[:bos_pos] + tag_tokens + all_tokens[bos_pos:]
                else:
                    all_tokens = tag_tokens + all_tokens
                print(f"Using tags: {tags}")

        # Strip EOS from end (we'll re-add after the new track)
        eos_id = tokenizer.vocab.get("EOS_None", tokenizer.vocab.get("EOS"))
        if eos_id is not None and all_tokens and all_tokens[-1] == eos_id:
            all_tokens = all_tokens[:-1]

        # Compute track IDs from existing tokens
        all_track_ids = compute_track_ids(all_tokens, tokenizer.vocab)

        # Next track index
        next_track_idx = num_existing_tracks

        # Auto-select instrument if not provided
        if instrument is None:
            genre = _extract_genre_from_tags(tags)
            pool = GENRE_INSTRUMENT_POOLS.get(genre, GENERIC_INSTRUMENT_POOLS)
            instrument = random.choice(pool.get(track_type, [0]))

        print(f"Adding track {next_track_idx + 1}: {track_type} (program {instrument} - {gm_program_name(instrument)})")

        # Get special token IDs
        track_start_id = tokenizer.vocab.get("TRACK_START")
        track_end_id = tokenizer.vocab.get("TRACK_END")

        # Build new track header: TRACK_START + Program_X + TRACKTYPE_X
        track_header = []
        if track_start_id is not None:
            track_header.append(track_start_id)

        program_token = f"Program_{instrument}"
        if program_token in tokenizer.vocab:
            track_header.append(tokenizer.vocab[program_token])

        track_type_token = f"TRACKTYPE_{track_type.upper()}"
        if track_type_token in tokenizer.vocab:
            track_header.append(tokenizer.vocab[track_type_token])

        all_tokens.extend(track_header)
        all_track_ids.extend([next_track_idx] * len(track_header))

        # Compute prefix length (tags + BOS) for sliding window preservation
        n_prefix = 0
        if track_start_id is not None and track_start_id in all_tokens:
            n_prefix = all_tokens.index(track_start_id)

        # Suppress EOS to prevent premature sequence termination
        eos_suppress = []
        for name in ["EOS", "EOS_None"]:
            tid = tokenizer.vocab.get(name)
            if tid is not None:
                eos_suppress.append(tid)

        # TRACK_END is a stop token -- model decides when to end the track
        track_stop_tokens = []
        for name in ["TRACK_END"]:
            tid = tokenizer.vocab.get(name)
            if tid is not None:
                track_stop_tokens.append(tid)

        amp_dtype = torch.float16 if device.type == "mps" else torch.bfloat16
        amp_enabled = device.type in ("cuda", "mps")

        if progress_callback:
            progress_callback(0.05, f'Generating {track_type} track...')

        def _on_token_progress(step, total):
            if progress_callback:
                progress_callback(0.05 + (step / total) * 0.85, f'Generating {track_type} track...')

        # Generate the new track
        prompt = torch.tensor([all_tokens], dtype=torch.long, device=device)
        track_ids_tensor = torch.tensor([all_track_ids], dtype=torch.long, device=device)

        with torch.autocast(device_type=device.type, dtype=amp_dtype, enabled=amp_enabled):
            output = model.generate(
                prompt,
                track_ids=track_ids_tensor,
                max_new_tokens=num_tokens_per_track,
                temperature=temperature,
                top_k=top_k,
                top_p=top_p,
                vocab_size=len(tokenizer.vocab),
                track_id_for_new_tokens=next_track_idx,
                suppress_tokens=eos_suppress,
                stop_tokens=track_stop_tokens,
                repetition_penalty=repetition_penalty,
                n_prefix_tokens=n_prefix,
                vocab=tokenizer.vocab,
                on_progress=_on_token_progress,
            )

        # Extract newly generated tokens
        new_tokens = output[0].tolist()[len(all_tokens):]
        all_tokens.extend(new_tokens)

        # If model didn't emit TRACK_END (hit max_new_tokens), add it
        if not new_tokens or new_tokens[-1] != track_end_id:
            if track_end_id is not None:
                all_tokens.append(track_end_id)

        # Add EOS
        if eos_id is not None:
            all_tokens.append(eos_id)

        track_content = [t for t in new_tokens if t != track_end_id]
        print(f"  Generated {len(track_content)} tokens for new track")
        print(f"  Total: {next_track_idx + 1} tracks, {len(all_tokens)} tokens")

        if progress_callback:
            progress_callback(0.90, 'Converting to MIDI...')

        # Convert to MIDI
        tokens_to_multitrack_midi(tokenizer, all_tokens, output_path)
        print(f"Output saved to: {output_path}")
        logger.info(f"Add-track complete: {len(all_tokens)} tokens, saved to {output_path}")

        return output_path
    except Exception as e:
        logger.exception(f"Add track failed: {e}")
        raise


def replace_track_in_midi(
    model: MultiTrackMusicTransformer,
    tokenizer,
    device: torch.device,
    midi_path: str,
    track_index: int,
    track_type: str = None,
    instrument: int = None,
    replace_bars: tuple = None,
    tags: str = None,
    num_tokens_per_track: int = 256,
    temperature: float = 1.0,
    top_k: int = 50,
    top_p: float = 0.95,
    repetition_penalty: float = 1.2,
    output_path: str = "generated_multitrack.mid",
    progress_callback=None,
) -> str:
    """
    Replace a track (or bars within a track) in an existing MIDI file.

    Tokenizes the existing MIDI, removes the target track or bar range,
    then generates a replacement conditioned on the remaining tracks.

    Args:
        model: Multi-track model
        tokenizer: MIDI tokenizer
        device: Device to run on
        midi_path: Path to existing MIDI file
        track_index: 0-based index of the track to replace
        track_type: Role for replacement track (None = keep original)
        instrument: MIDI program number for replacement (None = keep original)
        replace_bars: Bar range to replace (0-based). None = full track,
                     (start,) = from bar start to end, (start, end) = bar range.
        tags: Optional style tags like "jazz happy fast"
        num_tokens_per_track: Max tokens to generate for the replacement
        temperature: Sampling temperature
        top_k: Top-k sampling parameter
        top_p: Nucleus sampling parameter
        repetition_penalty: Penalize repeated tokens
        output_path: Where to save the output MIDI

    Returns:
        Path to output MIDI file
    """
    try:
        from pathlib import Path as _Path

        # Tokenize existing MIDI
        all_tokens, track_infos = tokenize_multitrack_midi(
            tokenizer, _Path(midi_path), use_tags=False
        )

        # Validate track index
        if track_index < 0 or track_index >= len(track_infos):
            raise ValueError(
                f"Track index {track_index} out of range "
                f"(file has {len(track_infos)} tracks)"
            )

        target = track_infos[track_index]
        orig_type = target["track_type"]
        orig_instrument = target["instrument"]

        # Default to original type/instrument if not overridden
        if track_type is None:
            track_type = orig_type
        if instrument is None:
            instrument = orig_instrument

        num_tracks = len(track_infos)
        track_start_id = tokenizer.vocab.get("TRACK_START")
        track_end_id = tokenizer.vocab.get("TRACK_END")
        eos_id = tokenizer.vocab.get("EOS_None", tokenizer.vocab.get("EOS"))

        if replace_bars is not None:
            # --- Partial replacement (bar range) ---
            bar_positions = target["bar_positions"]
            start_pos = target["start_token_pos"]
            end_pos = target["end_token_pos"]

            if not bar_positions:
                raise ValueError(f"Track {track_index + 1} has no bar markers")

            start_bar = replace_bars[0]
            has_end_bar = len(replace_bars) > 1
            end_bar = replace_bars[1] if has_end_bar else len(bar_positions) - 1

            if start_bar < 0 or start_bar >= len(bar_positions):
                raise ValueError(
                    f"Start bar {start_bar + 1} out of range "
                    f"(track has {len(bar_positions)} bars)"
                )
            if end_bar < start_bar or end_bar >= len(bar_positions):
                raise ValueError(
                    f"End bar {end_bar + 1} out of range "
                    f"(track has {len(bar_positions)} bars)"
                )

            # Token indices for the cut
            cut_start = bar_positions[start_bar]
            if has_end_bar and end_bar + 1 < len(bar_positions):
                # Replacing bars N-M: suffix starts at bar M+1
                cut_end = bar_positions[end_bar + 1]
            else:
                # Replacing from bar N to end: cut up to TRACK_END
                cut_end = end_pos - 1  # before TRACK_END token

            # Suffix: remaining bars + TRACK_END (empty if replacing to end)
            if has_end_bar and end_bar + 1 < len(bar_positions):
                suffix_tokens = all_tokens[cut_end:end_pos]  # remaining bars + TRACK_END
            else:
                suffix_tokens = [track_end_id] if track_end_id is not None else []

            # Estimate token budget from original content
            original_bar_tokens = cut_end - cut_start
            if not has_end_bar:
                # Replacing to end — use the provided num_tokens_per_track
                gen_budget = num_tokens_per_track
            else:
                # Replacing a range — budget based on original content (with headroom)
                gen_budget = int(original_bar_tokens * 1.5) if original_bar_tokens > 0 else num_tokens_per_track

            bars_desc = f"{start_bar + 1}-{end_bar + 1}" if has_end_bar else f"{start_bar + 1}-end"
            print(f"Replacing bars {bars_desc} of track {track_index + 1} "
                  f"({track_type}, {gm_program_name(instrument)})")
            print(f"  Original: {original_bar_tokens} tokens in replaced section")

            logger.info(
                f"Replacing bars {bars_desc} of track {track_index} in {midi_path}"
            )

            # Build the prompt sequence:
            # prefix (tags+BOS) + other tracks + target track prefix (up to cut point)
            # We need the target track at the END so the model can continue generating.

            # Find prefix (everything before first TRACK_START)
            first_track_start = track_infos[0]["start_token_pos"]
            prefix = all_tokens[:first_track_start]

            # Collect other tracks' tokens (in original order)
            other_tracks_tokens = []
            for i, info in enumerate(track_infos):
                if i != track_index:
                    other_tracks_tokens.extend(
                        all_tokens[info["start_token_pos"]:info["end_token_pos"]]
                    )

            # Target track prefix: from TRACK_START up to the cut point
            target_prefix = all_tokens[start_pos:cut_start]

            # Reassemble: prefix + other tracks + target track prefix
            prompt_tokens = prefix + other_tracks_tokens + target_prefix

        else:
            # --- Full track replacement ---
            start_pos = target["start_token_pos"]
            end_pos = target["end_token_pos"]
            suffix_tokens = []
            gen_budget = num_tokens_per_track

            print(f"Replacing track {track_index + 1}/{num_tracks}: "
                  f"{orig_type} -> {track_type} ({gm_program_name(instrument)})")

            logger.info(
                f"Replacing track {track_index} in {midi_path}, output={output_path}"
            )

            # Remove target track and reassemble
            # prefix + other tracks (target track removed, moved to end as new generation)
            first_track_start = track_infos[0]["start_token_pos"]
            prefix = all_tokens[:first_track_start]

            other_tracks_tokens = []
            for i, info in enumerate(track_infos):
                if i != track_index:
                    other_tracks_tokens.extend(
                        all_tokens[info["start_token_pos"]:info["end_token_pos"]]
                    )

            # Build prompt: prefix + other tracks + new track header
            prompt_tokens = prefix + other_tracks_tokens

        # Optionally prepend user-specified tags before BOS
        if tags:
            tag_tokens = parse_tags(tags, tokenizer)
            if tag_tokens:
                bos_id = tokenizer.vocab.get("BOS_None", tokenizer.vocab.get("BOS"))
                if bos_id is not None and bos_id in prompt_tokens:
                    bos_pos = prompt_tokens.index(bos_id)
                    prompt_tokens = prompt_tokens[:bos_pos] + tag_tokens + prompt_tokens[bos_pos:]
                else:
                    prompt_tokens = tag_tokens + prompt_tokens
                print(f"Using tags: {tags}")

        # Strip EOS if present
        if eos_id is not None and prompt_tokens and prompt_tokens[-1] == eos_id:
            prompt_tokens = prompt_tokens[:-1]

        # For full replacement, add the new track header
        if replace_bars is None:
            track_header = []
            if track_start_id is not None:
                track_header.append(track_start_id)

            program_token = f"Program_{instrument}"
            if program_token in tokenizer.vocab:
                track_header.append(tokenizer.vocab[program_token])

            track_type_token = f"TRACKTYPE_{track_type.upper()}"
            if track_type_token in tokenizer.vocab:
                track_header.append(tokenizer.vocab[track_type_token])

            prompt_tokens.extend(track_header)

        # Compute track IDs and determine the target's new track index
        all_track_ids = compute_track_ids(prompt_tokens, tokenizer.vocab)
        # The target track is now the last one in the sequence
        new_track_idx = max(all_track_ids) if all_track_ids else 0
        if new_track_idx == -1:
            new_track_idx = 0

        # For bar replacement, the target track prefix already has its track_id
        # assigned by compute_track_ids. New tokens continue that same track.
        # For full replacement, the header we just added gets the next track_id.

        # Compute prefix length (tags + BOS) for sliding window
        n_prefix = 0
        if track_start_id is not None and track_start_id in prompt_tokens:
            n_prefix = prompt_tokens.index(track_start_id)

        # Suppress EOS
        eos_suppress = []
        for name in ["EOS", "EOS_None"]:
            tid = tokenizer.vocab.get(name)
            if tid is not None:
                eos_suppress.append(tid)

        # Stop tokens: TRACK_END for full replacement / replacement to end
        # For bar range replacement with suffix, don't stop on TRACK_END
        # (we'll strip it and append suffix manually)
        track_stop_tokens = []
        has_suffix = replace_bars is not None and len(suffix_tokens) > 0 and suffix_tokens != ([track_end_id] if track_end_id is not None else [])
        if not has_suffix:
            for name in ["TRACK_END"]:
                tid = tokenizer.vocab.get(name)
                if tid is not None:
                    track_stop_tokens.append(tid)

        amp_dtype = torch.float16 if device.type == "mps" else torch.bfloat16
        amp_enabled = device.type in ("cuda", "mps")

        if progress_callback:
            progress_callback(0.05, f'Generating replacement {track_type} track...')

        def _on_token_progress(step, total):
            if progress_callback:
                progress_callback(0.05 + (step / total) * 0.85, f'Generating replacement {track_type} track...')

        # Generate
        prompt_tensor = torch.tensor([prompt_tokens], dtype=torch.long, device=device)
        track_ids_tensor = torch.tensor([all_track_ids], dtype=torch.long, device=device)

        with torch.autocast(device_type=device.type, dtype=amp_dtype, enabled=amp_enabled):
            output = model.generate(
                prompt_tensor,
                track_ids=track_ids_tensor,
                max_new_tokens=gen_budget,
                temperature=temperature,
                top_k=top_k,
                top_p=top_p,
                vocab_size=len(tokenizer.vocab),
                track_id_for_new_tokens=new_track_idx,
                suppress_tokens=eos_suppress,
                stop_tokens=track_stop_tokens,
                repetition_penalty=repetition_penalty,
                n_prefix_tokens=n_prefix,
                vocab=tokenizer.vocab,
                on_progress=_on_token_progress,
            )

        # Extract generated tokens
        new_tokens = output[0].tolist()[len(prompt_tokens):]
        final_tokens = list(prompt_tokens)
        final_tokens.extend(new_tokens)

        if has_suffix:
            # Bar range replacement: strip any TRACK_END from generated tokens,
            # then append suffix (remaining bars + TRACK_END)
            if track_end_id is not None:
                while final_tokens and final_tokens[-1] == track_end_id:
                    final_tokens.pop()
            final_tokens.extend(suffix_tokens)
        else:
            # Full replacement or replace-to-end: ensure TRACK_END
            if not new_tokens or new_tokens[-1] != track_end_id:
                if track_end_id is not None:
                    final_tokens.append(track_end_id)

        # Add EOS
        if eos_id is not None:
            final_tokens.append(eos_id)

        gen_content = [t for t in new_tokens if t != track_end_id]
        print(f"  Generated {len(gen_content)} tokens for replacement")
        print(f"  Total: {num_tracks} tracks, {len(final_tokens)} tokens")

        if progress_callback:
            progress_callback(0.90, 'Converting to MIDI...')

        # Convert to MIDI
        tokens_to_multitrack_midi(tokenizer, final_tokens, output_path)
        print(f"Output saved to: {output_path}")
        logger.info(f"Replace-track complete: {len(final_tokens)} tokens, saved to {output_path}")

        return output_path
    except Exception as e:
        logger.exception(f"Replace track failed: {e}")
        raise


def cover_midi(
    model: MultiTrackMusicTransformer,
    tokenizer,
    device: torch.device,
    midi_path: str,
    num_tracks: int = None,
    track_types: list = None,
    instruments: list = None,
    tags: str = None,
    num_tokens_per_track: int = 256,
    temperature: float = 1.0,
    top_k: int = 50,
    top_p: float = 0.95,
    repetition_penalty: float = 1.2,
    output_path: str = "generated_cover.mid",
    progress_callback=None,
) -> str:
    """
    Generate a cover of an existing MIDI file.

    Tokenizes the reference MIDI and uses its tracks as frozen context.
    New tracks are generated via cross-track attention conditioned on the
    reference, then the reference tracks are stripped from the output.

    Args:
        model: Multi-track model
        tokenizer: MIDI tokenizer
        device: Device to run on
        midi_path: Path to reference MIDI file
        num_tracks: Number of new tracks to generate (default: match reference)
        track_types: Roles for generated tracks (default: match reference)
        instruments: MIDI program numbers for generated tracks (default: auto)
        tags: Optional style tags like "jazz happy fast"
        num_tokens_per_track: Tokens to generate per track
        temperature: Sampling temperature
        top_k: Top-k sampling parameter
        top_p: Nucleus sampling parameter
        repetition_penalty: Penalize repeated tokens
        output_path: Where to save the output MIDI

    Returns:
        Path to output MIDI file
    """
    try:
        from pathlib import Path as _Path

        logger.info(f"Covering {midi_path}, output={output_path}")

        # Tokenize reference MIDI
        ref_tokens, ref_track_infos = tokenize_multitrack_midi(
            tokenizer, _Path(midi_path), use_tags=False
        )
        num_ref_tracks = len(ref_track_infos)
        print(f"Reference: {midi_path} ({num_ref_tracks} tracks, {len(ref_tokens)} tokens)")
        for info in ref_track_infos:
            print(f"  Track {info['track_idx'] + 1}: {info['track_type']} "
                  f"({gm_program_name(info['instrument'])})")

        # Default: generate same number of tracks as reference
        if num_tracks is None:
            num_tracks = num_ref_tracks

        # Default track types: match reference, or use genre-aware defaults
        if track_types is None:
            track_types = [info['track_type'] for info in ref_track_infos[:num_tracks]]
            # Pad if generating more tracks than reference has
            if len(track_types) < num_tracks:
                genre = _extract_genre_from_tags(tags)
                if genre and genre in GENRE_TRACK_DEFAULTS:
                    extras = [t for t in GENRE_TRACK_DEFAULTS[genre]
                              if t not in track_types]
                else:
                    extras = ["chords", "pad", "lead", "strings"]
                for t in extras:
                    if len(track_types) >= num_tracks:
                        break
                    track_types.append(t)

        # Default instruments: genre-aware pools
        if instruments is None:
            genre = _extract_genre_from_tags(tags)
            pool = GENRE_INSTRUMENT_POOLS.get(genre, GENERIC_INSTRUMENT_POOLS)
            instruments = [random.choice(pool.get(t, [0])) for t in track_types]

        while len(track_types) < num_tracks:
            track_types.append("other")
        while len(instruments) < num_tracks:
            instruments.append(0)

        track_summary = ", ".join(
            f"{t} ({gm_program_name(i)})"
            for t, i in zip(track_types, instruments)
        )
        print(f"Generating {num_tracks} new tracks: {track_summary}")

        # Optionally prepend user-specified tags before BOS
        all_tokens = list(ref_tokens)
        if tags:
            tag_tokens = parse_tags(tags, tokenizer)
            if tag_tokens:
                bos_id = tokenizer.vocab.get("BOS_None", tokenizer.vocab.get("BOS"))
                if bos_id is not None and bos_id in all_tokens:
                    bos_pos = all_tokens.index(bos_id)
                    all_tokens = all_tokens[:bos_pos] + tag_tokens + all_tokens[bos_pos:]
                else:
                    all_tokens = tag_tokens + all_tokens
                print(f"Using tags: {tags}")

        # Strip EOS from end (we'll re-add after the new tracks)
        eos_id = tokenizer.vocab.get("EOS_None", tokenizer.vocab.get("EOS"))
        if eos_id is not None and all_tokens and all_tokens[-1] == eos_id:
            all_tokens = all_tokens[:-1]

        # Record where reference tokens end (for stripping later)
        ref_end_pos = len(all_tokens)

        # Compute track IDs for reference tokens
        all_track_ids = compute_track_ids(all_tokens, tokenizer.vocab)

        # Get special token IDs
        track_start_id = tokenizer.vocab.get("TRACK_START")
        track_end_id = tokenizer.vocab.get("TRACK_END")

        # Compute prefix length (tags + BOS) for sliding window preservation
        n_prefix = 0
        if track_start_id is not None and track_start_id in all_tokens:
            n_prefix = all_tokens.index(track_start_id)

        # Suppress EOS to prevent premature sequence termination
        eos_suppress = []
        for name in ["EOS", "EOS_None"]:
            tid = tokenizer.vocab.get(name)
            if tid is not None:
                eos_suppress.append(tid)

        # TRACK_END is a stop token
        track_stop_tokens = []
        for name in ["TRACK_END"]:
            tid = tokenizer.vocab.get(name)
            if tid is not None:
                track_stop_tokens.append(tid)

        amp_dtype = torch.float16 if device.type == "mps" else torch.bfloat16
        amp_enabled = device.type in ("cuda", "mps")

        if progress_callback:
            progress_callback(0.0, 'Preparing cover generation...')

        # Generate each new track sequentially, conditioned on reference + prior new tracks
        for track_idx in range(num_tracks):
            track_type = track_types[track_idx]
            instrument = instruments[track_idx]
            # New tracks get IDs after the reference tracks
            new_track_id = num_ref_tracks + track_idx

            print(f"\nGenerating track {track_idx + 1}/{num_tracks}: "
                  f"{track_type} (program {instrument} - {gm_program_name(instrument)})")

            # Build track header
            track_header = []
            if track_start_id is not None:
                track_header.append(track_start_id)

            program_token = f"Program_{instrument}"
            if program_token in tokenizer.vocab:
                track_header.append(tokenizer.vocab[program_token])

            track_type_token = f"TRACKTYPE_{track_type.upper()}"
            if track_type_token in tokenizer.vocab:
                track_header.append(tokenizer.vocab[track_type_token])

            all_tokens.extend(track_header)
            all_track_ids.extend([new_track_id] * len(track_header))

            # Create prompt tensor
            prompt = torch.tensor([all_tokens], dtype=torch.long, device=device)
            track_ids_tensor = torch.tensor([all_track_ids], dtype=torch.long, device=device)

            def _on_token_progress(step, total, _tidx=track_idx):
                if progress_callback:
                    track_frac = (step / total) if total > 0 else 1.0
                    base = 0.05 + (_tidx / num_tracks) * 0.85
                    progress_callback(
                        base + track_frac * (0.85 / num_tracks),
                        f'Generating track {_tidx + 1}/{num_tracks} ({track_types[_tidx]})',
                    )

            if progress_callback:
                progress_callback(
                    0.05 + (track_idx / num_tracks) * 0.85,
                    f'Generating track {track_idx + 1}/{num_tracks} ({track_type})...',
                )

            with torch.autocast(device_type=device.type, dtype=amp_dtype, enabled=amp_enabled):
                output = model.generate(
                    prompt,
                    track_ids=track_ids_tensor,
                    max_new_tokens=num_tokens_per_track,
                    temperature=temperature,
                    top_k=top_k,
                    top_p=top_p,
                    vocab_size=len(tokenizer.vocab),
                    track_id_for_new_tokens=new_track_id,
                    suppress_tokens=eos_suppress,
                    stop_tokens=track_stop_tokens,
                    repetition_penalty=repetition_penalty,
                    n_prefix_tokens=n_prefix,
                    vocab=tokenizer.vocab,
                    on_progress=_on_token_progress,
                )

            # Extract newly generated tokens
            new_tokens = output[0].tolist()[len(all_tokens):]
            all_tokens.extend(new_tokens)
            all_track_ids.extend([new_track_id] * len(new_tokens))

            # Ensure TRACK_END
            if not new_tokens or new_tokens[-1] != track_end_id:
                if track_end_id is not None:
                    all_tokens.append(track_end_id)
                    all_track_ids.append(new_track_id)

            track_content = [t for t in new_tokens if t != track_end_id]
            print(f"  Generated {len(track_content)} tokens for track {track_idx + 1}")

        # Build output: prefix (tags + BOS) + only the newly generated tracks
        prefix_tokens = all_tokens[:n_prefix]
        new_track_tokens = all_tokens[ref_end_pos:]
        final_tokens = prefix_tokens + new_track_tokens

        # Add EOS
        if eos_id is not None:
            final_tokens.append(eos_id)

        print(f"\nCover: {len(final_tokens)} tokens ({num_tracks} new tracks, "
              f"reference tracks stripped)")

        if progress_callback:
            progress_callback(0.90, 'Converting to MIDI...')

        # Convert to MIDI
        tokens_to_multitrack_midi(tokenizer, final_tokens, output_path)
        print(f"Cover saved to: {output_path}")
        logger.info(f"Cover complete: {len(final_tokens)} tokens, saved to {output_path}")

        return output_path
    except Exception as e:
        logger.exception(f"Cover generation failed: {e}")
        raise
