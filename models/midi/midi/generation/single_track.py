import os
import torch
import logging

from ..model import MusicTransformer
from ..tokenization import (
    parse_tags, get_available_tags, tokens_to_midi,
)
from symusic import Score

logger = logging.getLogger(__name__)


def get_tokens_for_extend(
    tokenizer,
    midi_path: str,
    extend_from: float,
    max_context_tokens: int = 256,
) -> tuple[list[int], str]:
    """
    Extract tokens from a MIDI file for extension.

    Args:
        tokenizer: MIDI tokenizer
        midi_path: Path to MIDI file
        extend_from: Time position in seconds.
                     Positive = override mode (keep tokens up to this time)
                     Negative = append mode (use last N seconds as context)
        max_context_tokens: Maximum context tokens for append mode

    Returns:
        Tuple of (token_ids, mode) where mode is "override" or "append"
    """
    # Load MIDI to get timing info
    score = Score(midi_path)

    # Get tempo (BPM) - use first tempo or default to 120
    if score.tempos:
        bpm = score.tempos[0].qpm
    else:
        bpm = 120.0

    # Calculate ticks per second
    ticks_per_beat = score.ticks_per_quarter
    ticks_per_second = ticks_per_beat * bpm / 60.0

    # Get total duration
    total_ticks = score.end()
    total_seconds = total_ticks / ticks_per_second

    # Tokenize the file
    tokens = tokenizer(midi_path)
    if hasattr(tokens, 'ids'):
        token_ids = tokens.ids
    elif isinstance(tokens, list) and len(tokens) > 0:
        token_ids = tokens[0].ids if hasattr(tokens[0], 'ids') else tokens[0]
    else:
        return [], "override"

    # Build reverse vocab mapping for O(1) lookups
    id_to_token = {tid: name for name, tid in tokenizer.vocab.items()}

    # Assuming 4/4 time signature, each bar = 4 beats
    beats_per_bar = 4
    ticks_per_bar = ticks_per_beat * beats_per_bar

    if extend_from >= 0:
        # OVERRIDE MODE: Keep tokens up to extend_from time
        target_tick = int(extend_from * ticks_per_second)
        target_bar = target_tick // ticks_per_bar

        end_idx = 0
        current_bar = 0

        for idx, token_id in enumerate(token_ids):
            token_name = id_to_token.get(token_id)
            if token_name and token_name.startswith("Bar_"):
                current_bar += 1
                if current_bar >= target_bar:
                    end_idx = idx
                    break

        if end_idx == 0:
            end_idx = len(token_ids) // 2  # Fallback: use first half

        prompt_tokens = token_ids[:end_idx]
        print(f"Override mode: keeping first {len(prompt_tokens)} tokens (~{extend_from}s)")
        return prompt_tokens, "override"

    else:
        # APPEND MODE: Use last N seconds as context, keep full original
        context_seconds = abs(extend_from)
        context_tick = int(context_seconds * ticks_per_second)
        context_bar = context_tick // ticks_per_bar

        # Find where to start context (from end)
        total_bars = 0
        bar_positions = []
        for idx, token_id in enumerate(token_ids):
            token_name = id_to_token.get(token_id)
            if token_name and token_name.startswith("Bar_"):
                total_bars += 1
                bar_positions.append(idx)

        # Get tokens from last N bars
        start_bar = max(0, total_bars - context_bar)
        if start_bar < len(bar_positions):
            start_idx = bar_positions[start_bar]
        else:
            start_idx = max(0, len(token_ids) - max_context_tokens)

        prompt_tokens = token_ids[start_idx:]
        if len(prompt_tokens) > max_context_tokens:
            prompt_tokens = prompt_tokens[-max_context_tokens:]

        print(f"Append mode: using last {len(prompt_tokens)} tokens (~{context_seconds}s context) from {total_seconds:.1f}s song")
        return prompt_tokens, "append"


def generate_music(
    model: MusicTransformer,
    tokenizer,
    device: torch.device,
    prompt_path: str = None,
    extend_from: float = None,
    tags: str = None,
    num_tokens: int = 512,
    temperature: float = 1.0,
    top_k: int = 50,
    top_p: float = 0.95,
    repetition_penalty: float = 1.2,
    output_path: str = "generated.mid",
    progress_callback=None,
):
    """
    Generate a new piece of music.

    Args:
        model: Trained model
        tokenizer: MIDI tokenizer
        device: Device to run on
        prompt_path: Optional MIDI file to continue from
        extend_from: Time position to extend from (requires prompt_path).
                     Positive = override after this time
                     Negative = append (use last N seconds as context)
        tags: Optional style tags like "jazz happy fast"
        num_tokens: Number of tokens to generate
        temperature: Sampling temperature
        top_k: Top-k sampling parameter
        top_p: Nucleus sampling parameter
        repetition_penalty: Penalize repeated tokens (1.0 = disabled, >1.0 = less repetition)
        output_path: Where to save the generated MIDI
    """
    try:
        logger.info(f"Starting music generation: tokens={num_tokens}, temp={temperature}, output={output_path}")

        # Track extend mode for post-processing
        extend_mode = None
        original_midi_path = None

        # Parse tags if provided
        tag_tokens = []
        if tags:
            tag_tokens = parse_tags(tags, tokenizer)
            if tag_tokens:
                print(f"Using tags: {tags} -> {len(tag_tokens)} tag tokens")
                logger.info(f"Using tags: {tags} -> {len(tag_tokens)} tag tokens")
            else:
                print(f"Warning: No valid tags found in '{tags}'")
                print(f"Available tags: {get_available_tags()}")
                logger.warning(f"No valid tags found in '{tags}'")

        # Create starting prompt
        if prompt_path:
            if extend_from is not None:
                # Use extend mode
                prompt_tokens, extend_mode = get_tokens_for_extend(
                    tokenizer, prompt_path, extend_from, max_context_tokens=256
                )
                original_midi_path = prompt_path
            else:
                # Use provided MIDI as prompt (from beginning)
                tokens = tokenizer(prompt_path)
                if hasattr(tokens, 'ids'):
                    prompt_tokens = tokens.ids[:256]  # Use first 256 tokens as prompt
                else:
                    prompt_tokens = tokens[0].ids[:256]
                print(f"Using {len(prompt_tokens)} tokens from {prompt_path} as prompt")
        else:
            # Start with BOS token
            bos_token = tokenizer.vocab.get("BOS_None", tokenizer.vocab.get("BOS", 1))
            prompt_tokens = [bos_token]
            print("Generating from scratch (BOS token)")

        # Prepend tags to prompt
        prompt_tokens = tag_tokens + prompt_tokens

        prompt = torch.tensor([prompt_tokens], dtype=torch.long, device=device)

        if progress_callback:
            progress_callback(0.0, 'Preparing generation...')

        print(f"Generating {num_tokens} new tokens...")
        print(f"Settings: temperature={temperature}, top_k={top_k}, top_p={top_p}")

        # Generate (constrain to tokenizer's actual vocabulary size)
        tokenizer_vocab_size = len(tokenizer.vocab)

        # Suppress EOS tokens to prevent early stopping
        eos_suppress = []
        for name in ["EOS", "EOS_None"]:
            tid = tokenizer.vocab.get(name)
            if tid is not None:
                eos_suppress.append(tid)

        # Number of prefix tokens (tags + BOS) to preserve during sliding window
        n_prefix = len(prompt_tokens)

        def _on_token_progress(step, total):
            if progress_callback:
                # Token generation is ~5%-90% of overall progress
                frac = step / total
                progress_callback(0.05 + frac * 0.85, 'Generating music...')

        amp_dtype = torch.float16 if device.type == "mps" else torch.bfloat16
        with torch.autocast(device_type=device.type, dtype=amp_dtype, enabled=device.type in ("cuda", "mps")):
            output = model.generate(
                prompt,
                max_new_tokens=num_tokens,
                temperature=temperature,
                top_k=top_k,
                top_p=top_p,
                vocab_size=tokenizer_vocab_size,
                suppress_tokens=eos_suppress,
                repetition_penalty=repetition_penalty,
                n_prefix_tokens=n_prefix,
                vocab=tokenizer.vocab,
                on_progress=_on_token_progress,
            )

        # Convert to list
        generated_tokens = output[0].tolist()

        # Validate token bounds
        vocab_size = len(tokenizer.vocab)
        oob_tokens = [t for t in generated_tokens if t < 0 or t >= vocab_size]
        if oob_tokens:
            logger.warning(
                f"Generated {len(oob_tokens)} out-of-bounds tokens "
                f"(vocab_size={vocab_size}): {oob_tokens[:10]}"
            )

        # Remove BOS/EOS if present (miditok names them "BOS_None"/"EOS_None")
        bos_id = tokenizer.vocab.get("BOS_None", tokenizer.vocab.get("BOS", 1))
        if generated_tokens[0] == bos_id:
            generated_tokens = generated_tokens[1:]

        eos_id = tokenizer.vocab.get("EOS_None", tokenizer.vocab.get("EOS", 2))
        if eos_id in generated_tokens:
            generated_tokens = generated_tokens[:generated_tokens.index(eos_id)]

        print(f"Generated {len(generated_tokens)} tokens total")

        if progress_callback:
            progress_callback(0.90, 'Converting to MIDI...')

        # Handle append mode: merge with original MIDI
        if extend_mode == "append" and original_midi_path:
            # Generate to temp file first
            temp_output = output_path + ".temp.mid"
            tokens_to_midi(tokenizer, generated_tokens, temp_output)

            # Load original and generated MIDI
            original_score = Score(original_midi_path)
            generated_score = Score(temp_output)

            # Get the end time of original (where to start appending)
            original_end = original_score.end()

            # Shift all notes in generated score by original_end
            for track in generated_score.tracks:
                for note in track.notes:
                    note.time += original_end

            # Append generated tracks to original
            for gen_track in generated_score.tracks:
                # Find matching track in original or create new
                matched = False
                for orig_track in original_score.tracks:
                    if orig_track.program == gen_track.program:
                        orig_track.notes.extend(gen_track.notes)
                        matched = True
                        break
                if not matched:
                    original_score.tracks.append(gen_track)

            # Apply humanization and save
            from ..tokenization.midi_io import humanize_midi
            original_score = humanize_midi(original_score)
            original_score.dump_midi(output_path)

            # Clean up temp file
            os.remove(temp_output)
            print(f"\nAppended to original, saved to: {output_path}")
        else:
            # Normal generation or override mode
            tokens_to_midi(tokenizer, generated_tokens, output_path)
            print(f"\nGenerated music saved to: {output_path}")

        logger.info(f"Generated {len(generated_tokens)} tokens, saved to {output_path}")

        return output_path
    except Exception as e:
        logger.exception(f"Music generation failed: {e}")
        raise
