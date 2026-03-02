import 'package:json_annotation/json_annotation.dart';

part 'audio_generate_request.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class AudioGenerateRequest {
  AudioGenerateRequest({
    required this.model,
    required this.taskType,
    this.title,
    this.prompt,
    this.lyrics,
    this.negativePrompt,
    this.srcAudioPath,
    this.infillStart,
    this.infillEnd,
    this.stemName,
    this.trackClasses,
    this.repaintingStart,
    this.repaintingEnd,
    this.thinking,
    this.constrainedDecoding,
    this.guidanceScale,
    this.inferMethod,
    this.inferenceSteps,
    this.cfgIntervalStart,
    this.cfgIntervalEnd,
    this.shift,
    this.timeSignature,
    this.temperature,
    this.cfgScale,
    this.topP,
    this.repetitionPenalty,
    this.audioDuration,
    this.batchSize,
    this.useRandomSeed,
    this.audioFormat,
    this.workspaceId,
    this.lyricSheetId,
  });

  factory AudioGenerateRequest.fromJson(Map<String, dynamic> json) =>
      _$AudioGenerateRequestFromJson(json);

  @JsonKey(required: true, disallowNullValue: true)
  final String model;

  @JsonKey(required: true, disallowNullValue: true)
  final String taskType;

  // ---- metadata fields ----
  final String? title;

  // ---- content fields ----
  final String? prompt;
  final String? lyrics;
  final String? negativePrompt;

  // ---- source audio fields ----
  final String? srcAudioPath;
  final double? infillStart;
  final double? infillEnd;
  final String? stemName;
  final List<dynamic>? trackClasses;
  final double? repaintingStart;
  final double? repaintingEnd;

  // ---- inference parameters ----
  final bool? thinking;
  final bool? constrainedDecoding;
  final double? guidanceScale;
  final String? inferMethod;
  final int? inferenceSteps;
  final double? cfgIntervalStart;
  final double? cfgIntervalEnd;
  final double? shift;
  final String? timeSignature;
  final double? temperature;
  final double? cfgScale;
  final double? topP;
  final double? repetitionPenalty;
  final double? audioDuration;
  final int? batchSize;
  final bool? useRandomSeed;
  final String? audioFormat;
  final String? workspaceId;
  final String? lyricSheetId;

  Map<String, dynamic> toJson() => _$AudioGenerateRequestToJson(this);

  static const validTaskTypes = {
    'generate',
    'generate_long',
    'infill',
    'cover',
    'extract',
    'add_stem',
    'extend',
  };

  static const validStemNames = {
    'vocals',
    'drums',
    'bass',
    'guitar',
    'keyboard',
    'strings',
    'synth',
    'percussion',
    'brass',
    'woodwinds',
    'fx',
    'backing_vocals',
  };

  String? validate() {
    if (model.isEmpty) return 'model is required';

    if (!validTaskTypes.contains(taskType)) {
      return 'Invalid or missing task_type. '
          'Valid types: ${validTaskTypes.join(', ')}';
    }

    switch (taskType) {
      case 'generate':
      case 'generate_long':
        if (_isBlank(prompt)) return 'prompt is required for $taskType';
      case 'infill':
        if (_isBlank(srcAudioPath)) {
          return 'src_audio_path is required for infill';
        }
        if (infillStart == null) return 'infill_start is required for infill';
        if (infillEnd == null) return 'infill_end is required for infill';
      case 'cover':
        if (_isBlank(srcAudioPath)) {
          return 'src_audio_path is required for cover';
        }
      case 'extract':
        if (_isBlank(srcAudioPath)) {
          return 'src_audio_path is required for extract';
        }
        if (_isBlank(stemName)) return 'stem_name is required for extract';
        if (!validStemNames.contains(stemName)) {
          return 'Invalid stem_name. '
              'Valid options: ${validStemNames.join(', ')}';
        }
      case 'add_stem':
        if (_isBlank(srcAudioPath)) {
          return 'src_audio_path is required for add_stem';
        }
        if (_isBlank(stemName)) return 'stem_name is required for add_stem';
        if (!validStemNames.contains(stemName)) {
          return 'Invalid stem_name. '
              'Valid options: ${validStemNames.join(', ')}';
        }
      case 'extend':
        if (_isBlank(srcAudioPath)) {
          return 'src_audio_path is required for extend';
        }
    }

    return null;
  }

  static bool _isBlank(String? value) => value == null || value.isEmpty;
}
