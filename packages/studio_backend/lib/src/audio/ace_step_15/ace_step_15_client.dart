import 'dart:convert';

import 'package:studio_backend/src/audio/audio_model_client.dart';

/// Anticorruption layer for the ACE-Step 1.5 audio model.
///
/// Maps standardized diskrot API fields to ace_step_15-specific fields
/// before forwarding to the Modal endpoint.
class AceStep15Client extends AudioModelClient {
  AceStep15Client({required String baseUrl, super.apiKey, super.client})
      : _modelBase = baseUrl,
        super(baseUrl: baseUrl);

  final String _modelBase;

  static const _pollInterval = Duration(seconds: 3);
  static const _maxPollAttempts = 200; // ~10 minutes

  @override
  Map<String, dynamic> get capabilities => {
    'task_types': [
      'generate',
      'infill',
      'cover',
      'extract',
      'add_stem',
      'extend',
      'upload',
      'crop',
      'fade',
    ],
    'parameters': [
      'prompt',
      'lyrics',
      'negative_prompt',
      'temperature',
      'guidance_scale',
      'inference_steps',
      'audio_duration',
      'batch_size',
      'cfg_scale',
      'top_p',
      'repetition_penalty',
      'shift',
      'cfg_interval_start',
      'cfg_interval_end',
      'thinking',
      'constrained_decoding',
      'use_random_seed',
      'audio_format',
      'time_signature',
      'infer_method',
    ],
    'features': {
      'lora': true,
      'lyrics': true,
      'negative_prompt': true,
    },
  };

  @override
  Map<String, dynamic> get defaults => {
    'temperature': 0.85,
    'guidance_scale': 7.0,
    'inference_steps': 50,
    'duration': 150.0,
    'batch_size': 1,
    'cfg_scale': 2.0,
    'top_p': 0.9,
    'repetition_penalty': 1.0,
    'shift': 3.0,
    'cfg_interval_start': 0.0,
    'cfg_interval_end': 1.0,
    'thinking': false,
    'constrained_decoding': false,
    'use_random_seed': true,
    'lyrics': '[verse]\n'
        'Just who do\n'
        'you think you are?\n'
        '\n'
        'Better than who\n'
        'you were I hope\n'
        '\n'
        'But that man\n'
        "isn't that far\n"
        '\n'
        'A tendril tapping\n'
        'you on the shoulder\n'
        '\n'
        'reminding you to\n'
        '\n'
        '[prechorus]\n'
        '\n'
        'do do do\n'
        '\n'
        '[verse]\n'
        '\n'
        "It's so easy to just\n"
        'press buttons\n'
        'on a slop machine\n'
        '\n'
        'Satisfying nothing but ego (but ego)\n'
        '\n'
        'Run\n'
        'run\n'
        'run out the clock\n'
        '\n'
        'Spend a few years\n'
        'walking the block\n'
        'until they dump\n'
        'you into a plot\n'
        'and your obituary\n'
        'is gobbled up\n'
        'by the Dead Internet\n'
        '\n'
        'Dead Internet.\n'
        'Dead Internet.\n'
        'Dead Internet.\n'
        'Dead Internet.\n'
        'Dead Internet.\n',
    'prompt': 'dark art dance track, feel-bad winter vibes, eerie found recording',
  };

  @override
  Future<Map<String, dynamic>> submit(
    String taskType,
    Map<String, dynamic> payload, {
    required String userId,
  }) async {
    final mapped = _mapPayload(taskType, payload);
    mapped['user_id'] = userId;

    // Submit task via /release_task.
    final releaseResponse = await post('/release_task', mapped);
    final data = releaseResponse['data'] as Map<String, dynamic>;
    final taskId = data['task_id'] as String;

    // Poll /query_result until the task completes.
    return _pollForResult(taskId);
  }

  Future<Map<String, dynamic>> _pollForResult(String taskId) async {
    for (var i = 0; i < _maxPollAttempts; i++) {
      await Future.delayed(_pollInterval);

      final response = await post('/query_result', {
        'task_id_list': [taskId],
      });

      final data = response['data'] as List<dynamic>?;
      if (data == null || data.isEmpty) continue;

      final task = data.first as Map<String, dynamic>;
      final status = task['status'] as int?;

      if (status == 1) {
        // Complete – parse the stringified result array.
        final resultStr = task['result'] as String?;
        if (resultStr != null) {
          final results = jsonDecode(resultStr) as List<dynamic>;
          // Make any relative file URLs absolute so callers can fetch them.
          final resolved = results.map((r) {
            final map = r as Map<String, dynamic>;
            final file = map['file'] as String?;
            if (file != null && file.startsWith('/')) {
              return {...map, 'file': '$_modelBase$file'};
            }
            return map;
          }).toList();
          return {'results': resolved};
        }
        return task;
      }

      if (status == 2) {
        throw AudioModelException(
          500,
          'Task $taskId failed: ${task['progress_text'] ?? 'unknown error'}',
        );
      }

      // status == 0 → still processing, keep polling.
    }

    throw AudioModelException(
      504,
      'Task $taskId timed out after '
      '${_maxPollAttempts * _pollInterval.inSeconds}s',
    );
  }

  // ---------------------------------------------------------------------------
  // LoRA
  // ---------------------------------------------------------------------------

  @override
  Future<Map<String, dynamic>> getLoraList() => getRequest('/v1/lora/list');

  @override
  Future<Map<String, dynamic>> getLoraStatus() => getRequest('/v1/lora/status');

  @override
  Future<Map<String, dynamic>> loadLora(
    String loraPath, {
    String? adapterName,
  }) => post('/v1/lora/load', {
    'lora_path': loraPath,
    if (adapterName != null) 'adapter_name': adapterName,
  });

  @override
  Future<Map<String, dynamic>> unloadLora() => post('/v1/lora/unload', {});

  @override
  Future<Map<String, dynamic>> toggleLora(bool useLora) =>
      post('/v1/lora/toggle', {'use_lora': useLora});

  @override
  Future<Map<String, dynamic>> setLoraScale(
    double scale, {
    String? adapterName,
  }) => post('/v1/lora/scale', {
    'scale': scale,
    if (adapterName != null) 'adapter_name': adapterName,
  });

  // ---------------------------------------------------------------------------

  static const _taskTypeMap = {
    'generate': 'text2music',
    'infill': 'repaint',
    'cover': 'cover',
    'extract': 'extract',
    'add_stem': 'lego',
    'extend': 'repaint',
  };

  static const _fieldNameMap = {
    'infill_start': 'repainting_start',
    'infill_end': 'repainting_end',
    'negative_prompt': 'lm_negative_prompt',
    'temperature': 'lm_temperature',
    'cfg_scale': 'lm_cfg_scale',
    'top_p': 'lm_top_p',
    'repetition_penalty': 'lm_repetition_penalty',
  };

  Map<String, dynamic> _mapPayload(
    String taskType,
    Map<String, dynamic> payload,
  ) {
    return {
      'task_type': _taskTypeMap[taskType] ?? taskType,
      for (final entry in payload.entries)
        (_fieldNameMap[entry.key] ?? entry.key): entry.value,
    };
  }
}
