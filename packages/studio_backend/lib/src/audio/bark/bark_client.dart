import 'package:studio_backend/src/audio/audio_model_client.dart';

/// Anticorruption layer for the Bark TTS model.
///
/// Maps standardized diskrot API fields to Bark-specific fields
/// before forwarding to the Bark API server.
class BarkClient extends AudioModelClient {
  BarkClient({required String baseUrl, super.apiKey, super.client})
      : _modelBase = baseUrl,
        super(baseUrl: baseUrl);

  final String _modelBase;

  @override
  Map<String, dynamic> get capabilities => {
    'task_types': ['generate', 'generate_long'],
    'parameters': ['prompt', 'temperature'],
    'features': {
      'lora': false,
      'lyrics': false,
      'negative_prompt': false,
    },
  };

  @override
  Map<String, dynamic> get defaults => {
    'temperature': 0.7,
    'prompt': 'Consensus is dead',
  };

  @override
  Future<Map<String, dynamic>> submit(
    String taskType,
    Map<String, dynamic> payload, {
    required String userId,
  }) async {
    switch (taskType) {
      case 'generate':
        return _submitGenerate(payload);
      case 'generate_long':
        return _submitGenerateLong(payload);
      default:
        throw AudioModelException(
          400,
          'Bark does not support the "$taskType" task type',
        );
    }
  }

  Future<Map<String, dynamic>> _submitGenerate(
    Map<String, dynamic> payload,
  ) async {
    final mapped = _mapPayload(payload);
    final response = await post('/generate', mapped);
    return _wrapFileResponse(response);
  }

  Future<Map<String, dynamic>> _submitGenerateLong(
    Map<String, dynamic> payload,
  ) async {
    final prompt = payload['prompt'] as String? ?? '';
    final temperature = payload['temperature'] as num?;

    // Split the prompt into segments on double-newlines, falling back to
    // sentence boundaries (period followed by space).
    var segments = prompt
        .split(RegExp(r'\n\n+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (segments.length <= 1) {
      // No double-newline breaks — try splitting on sentences.
      segments = prompt
          .split(RegExp(r'(?<=\.)\s+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    final body = <String, dynamic>{
      'segments': segments,
      if (temperature != null) 'text_temp': temperature,
    };
    // Forward any Bark-native fields the caller may have included.
    if (payload.containsKey('history_prompt')) {
      body['history_prompt'] = payload['history_prompt'];
    }
    if (payload.containsKey('waveform_temp')) {
      body['waveform_temp'] = payload['waveform_temp'];
    }
    if (payload.containsKey('min_eos_p')) {
      body['min_eos_p'] = payload['min_eos_p'];
    }
    if (payload.containsKey('silence_duration_s')) {
      body['silence_duration_s'] = payload['silence_duration_s'];
    }

    final response = await post('/generate_long', body);
    return _wrapFileResponse(response);
  }

  Map<String, dynamic> _wrapFileResponse(Map<String, dynamic> response) {
    final file = response['file'] as String?;
    if (file != null) {
      return {
        'results': [
          {
            ...response,
            'file': '$_modelBase/output/$file',
          },
        ],
      };
    }
    return {'results': [response]};
  }

  // -------------------------------------------------------------------------

  static const _fieldNameMap = {
    'prompt': 'text',
    'temperature': 'text_temp',
  };

  Map<String, dynamic> _mapPayload(Map<String, dynamic> payload) {
    final mapped = <String, dynamic>{};
    for (final entry in payload.entries) {
      final key = _fieldNameMap[entry.key] ?? entry.key;
      mapped[key] = entry.value;
    }
    return mapped;
  }
}
