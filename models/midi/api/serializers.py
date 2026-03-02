"""
Request/Response serializers for the MIDI API.
"""

from rest_framework import serializers


class GenerateRequestSerializer(serializers.Serializer):
    """Serializer for single-track generation requests."""

    tags = serializers.CharField(
        required=False,
        allow_blank=True,
        help_text="Space-separated style tags (e.g., 'jazz happy fast')"
    )
    duration = serializers.IntegerField(
        default=30,
        min_value=5,
        max_value=30,
        help_text="Duration in seconds (max 30)"
    )
    bpm = serializers.IntegerField(
        default=120,
        min_value=40,
        max_value=200,
        help_text="Tempo in beats per minute"
    )
    temperature = serializers.FloatField(
        default=1.0,
        min_value=0.1,
        max_value=2.0,
        help_text="Sampling temperature (higher = more creative)"
    )
    top_k = serializers.IntegerField(
        default=50,
        min_value=0,
        max_value=500,
        help_text="Top-k sampling (0 to disable)"
    )
    top_p = serializers.FloatField(
        default=0.95,
        min_value=0.0,
        max_value=1.0,
        help_text="Nucleus sampling threshold"
    )
    repetition_penalty = serializers.FloatField(
        default=1.2,
        min_value=1.0,
        max_value=3.0,
        help_text="Penalize repeated tokens (1.0 = disabled, >1.0 = less repetition)"
    )
    humanize = serializers.ChoiceField(
        choices=['light', 'medium', 'heavy'],
        required=False,
        help_text="Post-process MIDI with humanization (light/medium/heavy)"
    )
    seed = serializers.IntegerField(
        required=False,
        min_value=0,
        help_text="Random seed for reproducibility"
    )
    model = serializers.CharField(
        default="default",
        required=False,
        help_text="Model name to use for generation (see GET /api/models/)"
    )

    def validate_model(self, value):
        """Validate that the requested model exists (loaded or on disk)."""
        from api.apps import ApiConfig
        available = ApiConfig.get_available_models()
        available_names = [m["name"] for m in available]
        if available_names and value not in available_names:
            raise serializers.ValidationError(
                f"Model '{value}' not found. Available: {available_names}"
            )
        return value


class GenerateWithPromptRequestSerializer(GenerateRequestSerializer):
    """Serializer for generation with MIDI prompt (file upload)."""

    prompt_midi = serializers.FileField(
        required=False,
        help_text="MIDI file to use as prompt"
    )
    extend_from = serializers.FloatField(
        required=False,
        help_text="Time position for extend mode. Positive=override, negative=append"
    )
    num_tracks = serializers.IntegerField(
        default=4,
        min_value=1,
        max_value=16,
        required=False,
        help_text="Number of tracks to generate when extending"
    )
    track_types = serializers.ListField(
        child=serializers.ChoiceField(choices=[
            'melody', 'bass', 'chords', 'drums', 'pad', 'lead', 'strings', 'other'
        ]),
        required=False,
        help_text="Track types for generated tracks"
    )
    instruments = serializers.ListField(
        child=serializers.IntegerField(min_value=-1, max_value=127),
        required=False,
        help_text="MIDI program numbers for each track (-1 for drums)"
    )


class MultitrackGenerateRequestSerializer(GenerateRequestSerializer):
    """Serializer for multi-track generation requests."""

    num_tracks = serializers.IntegerField(
        default=4,
        min_value=1,
        max_value=16,
        help_text="Number of tracks to generate"
    )
    track_types = serializers.ListField(
        child=serializers.ChoiceField(choices=[
            'melody', 'bass', 'chords', 'drums', 'pad', 'lead', 'strings', 'other'
        ]),
        required=False,
        help_text="Track types (e.g., ['melody', 'bass', 'chords', 'drums'])"
    )
    instruments = serializers.ListField(
        child=serializers.IntegerField(min_value=-1, max_value=127),
        required=False,
        help_text="MIDI program numbers for each track (-1 for drums)"
    )

class AddTrackRequestSerializer(GenerateRequestSerializer):
    """Serializer for adding a track to an existing MIDI file."""

    prompt_midi = serializers.FileField(
        required=True,
        help_text="Existing MIDI file to add a track to"
    )
    track_type = serializers.ChoiceField(
        choices=['melody', 'bass', 'chords', 'drums', 'pad', 'lead', 'strings', 'other'],
        default='melody',
        help_text="Role for the new track"
    )
    instrument = serializers.IntegerField(
        required=False,
        min_value=-1,
        max_value=127,
        help_text="MIDI program number for the new track (-1 for drums, None = auto-select)"
    )

class ReplaceTrackRequestSerializer(GenerateRequestSerializer):
    """Serializer for replacing a track (or bars) in an existing MIDI file."""

    prompt_midi = serializers.FileField(
        required=True,
        help_text="Existing MIDI file to replace a track in"
    )
    track_index = serializers.IntegerField(
        required=True,
        min_value=1,
        help_text="Track number to replace (1-based)"
    )
    track_type = serializers.ChoiceField(
        choices=['melody', 'bass', 'chords', 'drums', 'pad', 'lead', 'strings', 'other'],
        required=False,
        help_text="New role for the track (None = keep original)"
    )
    instrument = serializers.IntegerField(
        required=False,
        min_value=-1,
        max_value=127,
        help_text="New MIDI program number (-1 for drums, None = keep original)"
    )

    replace_bars = serializers.CharField(
        required=False,
        help_text="Bar range to replace (1-based). Examples: '8' (bar 8 to end), '8-16' (bars 8 through 16)"
    )

    def validate_replace_bars(self, value):
        """Parse and validate the bar range string."""
        if not value:
            return None
        value = value.strip().rstrip('-')
        parts = value.split('-')
        try:
            if len(parts) == 1:
                start = int(parts[0])
                if start < 1:
                    raise serializers.ValidationError("Bar number must be >= 1")
                return (start,)
            elif len(parts) == 2:
                start, end = int(parts[0]), int(parts[1])
                if start < 1 or end < 1:
                    raise serializers.ValidationError("Bar numbers must be >= 1")
                if end < start:
                    raise serializers.ValidationError("End bar must be >= start bar")
                return (start, end)
            else:
                raise serializers.ValidationError("Invalid bar range format")
        except ValueError:
            raise serializers.ValidationError(
                "Invalid bar range. Use '8' (from bar 8 to end) or '8-16' (bars 8 through 16)"
            )


class CoverRequestSerializer(GenerateRequestSerializer):
    """Serializer for cover generation requests (re-generate conditioned on reference)."""

    prompt_midi = serializers.FileField(
        required=True,
        help_text="Reference MIDI file to cover"
    )
    num_tracks = serializers.IntegerField(
        required=False,
        min_value=1,
        max_value=16,
        help_text="Number of tracks to generate (default: match reference)"
    )
    track_types = serializers.ListField(
        child=serializers.ChoiceField(choices=[
            'melody', 'bass', 'chords', 'drums', 'pad', 'lead', 'strings', 'other'
        ]),
        required=False,
        help_text="Track types for generated tracks (default: match reference)"
    )
    instruments = serializers.ListField(
        child=serializers.IntegerField(min_value=-1, max_value=127),
        required=False,
        help_text="MIDI program numbers for each track (-1 for drums)"
    )


class TaskResponseSerializer(serializers.Serializer):
    """Serializer for task submission response."""

    task_id = serializers.CharField()
    status = serializers.CharField()
    status_url = serializers.CharField()


class TaskStatusSerializer(serializers.Serializer):
    """Serializer for task status response."""

    task_id = serializers.CharField()
    status = serializers.ChoiceField(choices=['pending', 'processing', 'complete', 'failed'])
    download_url = serializers.CharField(required=False)
    mp3_download_url = serializers.CharField(required=False)
    expires_at = serializers.DateTimeField(required=False)
    error = serializers.CharField(required=False)


class ConvertRequestSerializer(serializers.Serializer):
    """Serializer for MIDI-to-MP3 conversion requests."""

    midi_file = serializers.FileField(
        required=True,
        help_text="MIDI file to convert to MP3"
    )


class TagsResponseSerializer(serializers.Serializer):
    """Serializer for available tags response."""

    genres = serializers.ListField(child=serializers.CharField())
    moods = serializers.ListField(child=serializers.CharField())
    tempos = serializers.ListField(child=serializers.CharField())


class PretokenizeRequestSerializer(serializers.Serializer):
    """Serializer for pretokenization requests."""

    midi_dir = serializers.CharField(default='midi_files')
    output = serializers.CharField(default='checkpoints/token_cache.pkl')
    single_track = serializers.BooleanField(default=False)
    use_tags = serializers.BooleanField(default=True)
    skip_validation = serializers.BooleanField(default=False)
    validate_only = serializers.BooleanField(default=False)
    max_tracks = serializers.IntegerField(default=16, min_value=1, max_value=16)
    workers = serializers.IntegerField(required=False, min_value=1, max_value=32)
    checkpoint_interval = serializers.IntegerField(default=500, min_value=100)
    metadata = serializers.CharField(required=False, allow_blank=True)
    max_files = serializers.IntegerField(required=False, min_value=1)


class ScanRequestSerializer(serializers.Serializer):
    """Serializer for MIDI directory scan requests."""

    midi_dir = serializers.CharField(default='midi_files')
    metadata = serializers.CharField(required=False, allow_blank=True)


class StageRequestSerializer(serializers.Serializer):
    """Serializer for staging selected MIDI files via symlinks."""

    source_dir = serializers.CharField()
    files = serializers.ListField(
        child=serializers.CharField(),
        min_length=1,
    )


class BrowseRequestSerializer(serializers.Serializer):
    """Serializer for server-side directory browse requests."""

    path = serializers.CharField(default='.')
    file_extensions = serializers.ListField(
        child=serializers.CharField(),
        required=False,
    )


class TrainingRequestSerializer(serializers.Serializer):
    """Serializer for training requests."""

    midi_dir = serializers.CharField(default='midi_files')
    checkpoint_dir = serializers.CharField(default='checkpoints')
    config = serializers.CharField(required=False, allow_blank=True)
    epochs = serializers.IntegerField(required=False, min_value=1, max_value=1000)
    batch_size = serializers.IntegerField(required=False, min_value=1)
    lr = serializers.FloatField(required=False, min_value=1e-8)
    grad_accum = serializers.IntegerField(required=False, min_value=1)
    load_from = serializers.CharField(required=False, allow_blank=True)
    finetune = serializers.BooleanField(default=False)
    freeze_layers = serializers.IntegerField(default=0, min_value=0)
    lora = serializers.BooleanField(default=False)
    lora_rank = serializers.IntegerField(default=8, min_value=1)
    lora_alpha = serializers.FloatField(default=16.0, min_value=0.1)
    no_warmup = serializers.BooleanField(default=False)
    debug = serializers.BooleanField(default=False)
    max_files = serializers.IntegerField(required=False, min_value=1)

    # Advanced config overrides
    d_model = serializers.IntegerField(required=False, min_value=64)
    n_heads = serializers.IntegerField(required=False, min_value=1)
    n_layers = serializers.IntegerField(required=False, min_value=1)
    seq_length = serializers.IntegerField(required=False, min_value=128)
    val_split = serializers.FloatField(required=False, min_value=0.0, max_value=0.5)
    early_stopping_patience = serializers.IntegerField(required=False, min_value=1)
    warmup_pct = serializers.FloatField(required=False, min_value=0.0, max_value=1.0)
    scheduler = serializers.ChoiceField(
        choices=['cosine', 'onecycle'], required=False,
    )
    dropout = serializers.FloatField(required=False, min_value=0.0, max_value=0.9)
    weight_decay = serializers.FloatField(required=False, min_value=0.0)
    grad_clip_norm = serializers.FloatField(required=False, min_value=0.0)
    use_tags = serializers.BooleanField(required=False)
    use_compile = serializers.BooleanField(required=False)

    def validate(self, data):
        if data.get('lora') and not data.get('load_from'):
            raise serializers.ValidationError(
                "LoRA requires 'load_from' to specify the base model checkpoint."
            )
        return data


class DiagnosisRequestSerializer(serializers.Serializer):
    """Serializer for diagnosis requests."""

    command = serializers.ChoiceField(
        choices=['tokens', 'generation', 'all'], default='all',
    )
    # tokens options
    cache = serializers.CharField(
        default='checkpoints/token_cache.pkl', required=False,
    )
    tokenizer = serializers.CharField(required=False, allow_blank=True)
    json_report = serializers.CharField(required=False, allow_blank=True)
    # generation options
    checkpoint = serializers.CharField(
        default='checkpoints/best_model.pt', required=False,
    )
    samples = serializers.IntegerField(
        default=3, required=False, min_value=1, max_value=10,
    )
    seed = serializers.IntegerField(default=42, required=False)
    # all options
    checkpoint_dir = serializers.CharField(
        default='checkpoints', required=False,
    )


class DownloadDataRequestSerializer(serializers.Serializer):
    """Serializer for training data download requests."""

    output_dir = serializers.CharField(default='midi_files')


class AutotuneRequestSerializer(serializers.Serializer):
    """Serializer for auto-tune config generation requests."""

    midi_dir = serializers.CharField(default='midi_files')
    checkpoint_dir = serializers.CharField(default='checkpoints')
