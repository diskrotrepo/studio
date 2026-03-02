// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_generate_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AudioGenerateRequest _$AudioGenerateRequestFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    requiredKeys: const ['model', 'task_type'],
    disallowNullValues: const ['model', 'task_type'],
  );
  return AudioGenerateRequest(
    model: json['model'] as String,
    taskType: json['task_type'] as String,
    title: json['title'] as String?,
    prompt: json['prompt'] as String?,
    lyrics: json['lyrics'] as String?,
    negativePrompt: json['negative_prompt'] as String?,
    srcAudioPath: json['src_audio_path'] as String?,
    infillStart: (json['infill_start'] as num?)?.toDouble(),
    infillEnd: (json['infill_end'] as num?)?.toDouble(),
    stemName: json['stem_name'] as String?,
    trackClasses: json['track_classes'] as List<dynamic>?,
    repaintingStart: (json['repainting_start'] as num?)?.toDouble(),
    repaintingEnd: (json['repainting_end'] as num?)?.toDouble(),
    thinking: json['thinking'] as bool?,
    constrainedDecoding: json['constrained_decoding'] as bool?,
    guidanceScale: (json['guidance_scale'] as num?)?.toDouble(),
    inferMethod: json['infer_method'] as String?,
    inferenceSteps: (json['inference_steps'] as num?)?.toInt(),
    cfgIntervalStart: (json['cfg_interval_start'] as num?)?.toDouble(),
    cfgIntervalEnd: (json['cfg_interval_end'] as num?)?.toDouble(),
    shift: (json['shift'] as num?)?.toDouble(),
    timeSignature: json['time_signature'] as String?,
    temperature: (json['temperature'] as num?)?.toDouble(),
    cfgScale: (json['cfg_scale'] as num?)?.toDouble(),
    topP: (json['top_p'] as num?)?.toDouble(),
    repetitionPenalty: (json['repetition_penalty'] as num?)?.toDouble(),
    audioDuration: (json['audio_duration'] as num?)?.toDouble(),
    batchSize: (json['batch_size'] as num?)?.toInt(),
    useRandomSeed: json['use_random_seed'] as bool?,
    audioFormat: json['audio_format'] as String?,
    workspaceId: json['workspace_id'] as String?,
    lyricSheetId: json['lyric_sheet_id'] as String?,
  );
}

Map<String, dynamic> _$AudioGenerateRequestToJson(
  AudioGenerateRequest instance,
) => <String, dynamic>{
  'model': instance.model,
  'task_type': instance.taskType,
  'title': ?instance.title,
  'prompt': ?instance.prompt,
  'lyrics': ?instance.lyrics,
  'negative_prompt': ?instance.negativePrompt,
  'src_audio_path': ?instance.srcAudioPath,
  'infill_start': ?instance.infillStart,
  'infill_end': ?instance.infillEnd,
  'stem_name': ?instance.stemName,
  'track_classes': ?instance.trackClasses,
  'repainting_start': ?instance.repaintingStart,
  'repainting_end': ?instance.repaintingEnd,
  'thinking': ?instance.thinking,
  'constrained_decoding': ?instance.constrainedDecoding,
  'guidance_scale': ?instance.guidanceScale,
  'infer_method': ?instance.inferMethod,
  'inference_steps': ?instance.inferenceSteps,
  'cfg_interval_start': ?instance.cfgIntervalStart,
  'cfg_interval_end': ?instance.cfgIntervalEnd,
  'shift': ?instance.shift,
  'time_signature': ?instance.timeSignature,
  'temperature': ?instance.temperature,
  'cfg_scale': ?instance.cfgScale,
  'top_p': ?instance.topP,
  'repetition_penalty': ?instance.repetitionPenalty,
  'audio_duration': ?instance.audioDuration,
  'batch_size': ?instance.batchSize,
  'use_random_seed': ?instance.useRandomSeed,
  'audio_format': ?instance.audioFormat,
  'workspace_id': ?instance.workspaceId,
  'lyric_sheet_id': ?instance.lyricSheetId,
};
