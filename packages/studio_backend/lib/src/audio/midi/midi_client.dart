import 'package:studio_backend/src/audio/audio_model_client.dart';
import 'package:studio_backend/src/audio/task_status_values.dart';

/// Anticorruption layer for the MIDI generation model.
///
/// Maps standardized diskrot API fields to MIDI-specific fields
/// before forwarding to the MIDI Django API server.
class MidiClient extends AudioModelClient {
  MidiClient({required String baseUrl, super.apiKey, super.client})
      : _modelBase = baseUrl,
        super(baseUrl: baseUrl);

  final String _modelBase;

  static const _pollInterval = Duration(seconds: 3);
  static const _maxPollAttempts = 200; // ~10 minutes

  @override
  Map<String, dynamic> get capabilities => {
    'task_types': [
      'generate',
      'cover',
      'add_stem',
      'replace_track',
      'extend',
      'upload',
      'crop',
      'fade',
    ],
    'parameters': [
      'prompt',
      'audio_duration',
      'bpm',
      'temperature',
      'top_k',
      'top_p',
      'repetition_penalty',
      'humanize',
      'seed',
    ],
    'features': {
      'lora': false,
      'lyrics': false,
      'negative_prompt': false,
    },
  };

  @override
  Map<String, dynamic> get defaults => {
    'temperature': 0.85,
    'top_p': 0.9,
    'repetition_penalty': 1.2,
    'audio_duration': 30.0,
    'prompt': 'jazz piano trio, smooth chords, walking bass, brush drums, '
        '120 BPM, swing feel, relaxed mood',
  };

  @override
  Future<Map<String, dynamic>> submit(
    String taskType,
    Map<String, dynamic> payload, {
    required String userId,
  }) async {
    final endpoint = _taskTypeEndpoints[taskType];
    if (endpoint == null) {
      throw AudioModelException(
        400,
        'MIDI model does not support task type "$taskType". '
        'Supported: ${_taskTypeEndpoints.keys.join(', ')}',
      );
    }

    final mapped = _mapPayload(payload);
    final response = await post(endpoint, mapped);
    final taskId = response['task_id'] as String;

    // Poll /api/tasks/<taskId>/ until the Celery task completes.
    return _pollForResult(taskId);
  }

  @override
  Future<bool> healthCheck() async {
    try {
      await getRequest('/api/health/');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> _pollForResult(String taskId) async {
    for (var i = 0; i < _maxPollAttempts; i++) {
      await Future.delayed(_pollInterval);

      final response = await getRequest('/api/tasks/$taskId/');
      final status = response['status'] as String?;

      if (status == TaskStatusValues.complete) {
        final results = <Map<String, dynamic>>[];
        final downloadUrl = response['download_url'] as String?;
        final mp3DownloadUrl = response['mp3_download_url'] as String?;

        // Prefer MP3 download URL, fall back to MIDI download URL.
        final fileUrl = mp3DownloadUrl ?? downloadUrl;
        if (fileUrl != null) {
          results.add({
            'file': _resolveUrl(fileUrl),
            if (downloadUrl != null) 'midi_file': _resolveUrl(downloadUrl),
          });
        }

        return {'results': results};
      }

      if (status == TaskStatusValues.failed) {
        throw AudioModelException(
          500,
          'MIDI task $taskId failed: '
          '${response['error'] ?? 'unknown error'}',
        );
      }

      // 'pending' or 'processing' → keep polling.
    }

    throw AudioModelException(
      504,
      'MIDI task $taskId timed out after '
      '${_maxPollAttempts * _pollInterval.inSeconds}s',
    );
  }

  String _resolveUrl(String url) =>
      url.startsWith('/') ? '$_modelBase$url' : url;

  // ---------------------------------------------------------------------------

  static const _taskTypeEndpoints = {
    'generate': '/api/generate/',
    'cover': '/api/generate/cover/',
    'add_stem': '/api/generate/add-track/',
    'replace_track': '/api/generate/replace-track/',
    'extend': '/api/generate/',
  };

  static const _fieldNameMap = {
    'prompt': 'tags',
    'audio_duration': 'duration',
  };

  Map<String, dynamic> _mapPayload(Map<String, dynamic> payload) {
    final mapped = <String, dynamic>{};
    for (final entry in payload.entries) {
      if (entry.value == null) continue;
      final key = _fieldNameMap[entry.key] ?? entry.key;
      mapped[key] = entry.value;
    }
    return mapped;
  }
}
