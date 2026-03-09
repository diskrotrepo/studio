import 'dart:convert';

import 'package:studio_backend/src/audio/audio_model_client.dart';

/// Anticorruption layer for the LTX-2 audio model.
///
/// Maps standardized diskrot API fields to LTX-2-specific fields
/// before forwarding to the LTX-2 endpoint.
class LtxClient extends AudioModelClient {
  LtxClient({required String baseUrl, super.apiKey, super.client})
      : _modelBase = baseUrl,
        super(baseUrl: baseUrl);

  final String _modelBase;

  static const _pollInterval = Duration(seconds: 3);
  static const _maxPollAttempts = 200; // ~10 minutes

  @override
  Map<String, dynamic> get capabilities => {
    'task_types': [
      'generate',
    ],
    'parameters': [
      'prompt',
      'negative_prompt',
      'guidance_scale',
      'audio_duration',
      'batch_size',
      'num_frames',
      'frame_rate',
      'seed',
      'enhance_prompt',
      'audio_cfg_guidance_scale',
      'audio_stg_guidance_scale',
      'audio_rescale_scale',
    ],
    'features': {
      'lora': true,
      'lyrics': false,
      'negative_prompt': true,
    },
  };

  @override
  Map<String, dynamic> get defaults => {
    'num_frames': 121,
    'frame_rate': 24.0,
    'audio_cfg_guidance_scale': 7.0,
    'audio_stg_guidance_scale': 1.0,
    'audio_rescale_scale': 0.7,
    'batch_size': 1,
    'enhance_prompt': false,
    'prompt': 'cinematic ambient soundscape, dark atmospheric drone',
  };

  @override
  Future<Map<String, dynamic>> submit(
    String taskType,
    Map<String, dynamic> payload, {
    required String userId,
  }) async {
    final mapped = _mapPayload(taskType, payload);
    mapped['user_id'] = userId;

    final releaseResponse = await post('/release_task', mapped);
    final data = releaseResponse['data'] as Map<String, dynamic>;
    final taskId = data['task_id'] as String;

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
        final resultStr = task['result'] as String?;
        if (resultStr != null) {
          final results = jsonDecode(resultStr) as List<dynamic>;
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
    'generate': 'audio_only',
  };

  static const _fieldNameMap = {
    'guidance_scale': 'audio_cfg_guidance_scale',
    'negative_prompt': 'negative_prompt',
  };

  Map<String, dynamic> _mapPayload(
    String taskType,
    Map<String, dynamic> payload,
  ) {
    final frameRate = (payload['frame_rate'] as num?)?.toDouble() ??
        (defaults['frame_rate'] as num).toDouble();

    return {
      'task_type': _taskTypeMap[taskType] ?? taskType,
      for (final entry in payload.entries)
        if (entry.key == 'audio_duration')
          'num_frames':
              ((entry.value as num).toDouble() * frameRate).round()
        else
          (_fieldNameMap[entry.key] ?? entry.key): entry.value,
    };
  }
}
