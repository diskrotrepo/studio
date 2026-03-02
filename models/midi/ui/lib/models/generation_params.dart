class GenerationParams {
  final String? tags;
  final int duration;
  final int bpm;
  final double temperature;
  final int topK;
  final double topP;
  final double repetitionPenalty;
  final String? humanize;
  final int? seed;
  final double? extendFrom;
  final String model;

  const GenerationParams({
    this.tags,
    this.duration = 30,
    this.bpm = 120,
    this.temperature = 0.8,
    this.topK = 30,
    this.topP = 0.85,
    this.repetitionPenalty = 1.2,
    this.humanize,
    this.seed,
    this.extendFrom,
    this.model = 'default',
  });

  GenerationParams copyWith({
    String? tags,
    int? duration,
    int? bpm,
    double? temperature,
    int? topK,
    double? topP,
    double? repetitionPenalty,
    String? humanize,
    int? seed,
    double? extendFrom,
    String? model,
    bool clearTags = false,
    bool clearHumanize = false,
    bool clearSeed = false,
    bool clearExtendFrom = false,
  }) {
    return GenerationParams(
      tags: clearTags ? null : (tags ?? this.tags),
      duration: duration ?? this.duration,
      bpm: bpm ?? this.bpm,
      temperature: temperature ?? this.temperature,
      topK: topK ?? this.topK,
      topP: topP ?? this.topP,
      repetitionPenalty: repetitionPenalty ?? this.repetitionPenalty,
      humanize: clearHumanize ? null : (humanize ?? this.humanize),
      seed: clearSeed ? null : (seed ?? this.seed),
      extendFrom: clearExtendFrom ? null : (extendFrom ?? this.extendFrom),
      model: model ?? this.model,
    );
  }

  factory GenerationParams.fromJson(Map<String, dynamic> json) {
    return GenerationParams(
      tags: json['tags'] as String?,
      duration: json['duration'] as int? ?? 30,
      bpm: json['bpm'] as int? ?? 120,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.8,
      topK: json['top_k'] as int? ?? 30,
      topP: (json['top_p'] as num?)?.toDouble() ?? 0.85,
      repetitionPenalty: (json['repetition_penalty'] as num?)?.toDouble() ?? 1.2,
      humanize: json['humanize'] as String?,
      seed: json['seed'] as int?,
      extendFrom: (json['extend_from'] as num?)?.toDouble(),
      model: json['model'] as String? ?? 'default',
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'duration': duration,
      'bpm': bpm,
      'temperature': temperature,
      'top_k': topK,
      'top_p': topP,
      'repetition_penalty': repetitionPenalty,
      'model': model,
    };
    if (tags != null && tags!.isNotEmpty) json['tags'] = tags;
    if (humanize != null) json['humanize'] = humanize;
    if (seed != null) json['seed'] = seed;
    if (extendFrom != null) json['extend_from'] = extendFrom;
    return json;
  }

  /// For multipart form fields (all values as strings).
  Map<String, String> toFormFields() {
    final fields = <String, String>{
      'duration': duration.toString(),
      'bpm': bpm.toString(),
      'temperature': temperature.toString(),
      'top_k': topK.toString(),
      'top_p': topP.toString(),
      'repetition_penalty': repetitionPenalty.toString(),
      'model': model,
    };
    if (tags != null && tags!.isNotEmpty) fields['tags'] = tags!;
    if (humanize != null) fields['humanize'] = humanize!;
    if (seed != null) fields['seed'] = seed.toString();
    if (extendFrom != null) fields['extend_from'] = extendFrom.toString();
    return fields;
  }
}
