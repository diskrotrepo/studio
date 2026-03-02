import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/generation_params.dart';
import '../models/multitrack_params.dart';
import '../models/edit_params.dart';
import '../models/picked_file.dart';
import '../models/tags_response.dart';
import '../models/health_status.dart';

class ApiException implements Exception {
  final int statusCode;
  final String body;

  ApiException(this.statusCode, this.body);

  @override
  String toString() => 'ApiException($statusCode): $body';
}

class ApiClient {
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  // ---------------------------------------------------------------------------
  // Health
  // ---------------------------------------------------------------------------

  Future<HealthStatus> getHealth() async {
    final response = await _client.get(ApiConfig.uri('/api/health/'));
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    return HealthStatus.fromJson(jsonDecode(response.body));
  }

  // ---------------------------------------------------------------------------
  // Models
  // ---------------------------------------------------------------------------

  Future<List<String>> getModels() async {
    final response = await _client.get(ApiConfig.uri('/api/models/'));
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final models = data['models'] as List<dynamic>;
    return models.map((m) => (m as Map<String, dynamic>)['name'] as String).toList();
  }

  // ---------------------------------------------------------------------------
  // Tags
  // ---------------------------------------------------------------------------

  Future<TagsResponse> getTags() async {
    final response = await _client.get(ApiConfig.uri('/api/tags/'));
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    return TagsResponse.fromJson(jsonDecode(response.body));
  }

  // ---------------------------------------------------------------------------
  // Single-track generation
  // ---------------------------------------------------------------------------

  Future<String> generateSingleTrack(
    GenerationParams params, {
    PickedFile? promptMidi,
  }) async {
    if (promptMidi != null) {
      return _multipartPost(
        '/api/generate/',
        params.toFormFields(),
        promptMidi,
      );
    }

    final response = await _client.post(
      ApiConfig.uri('/api/generate/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(params.toJson()),
    );

    if (response.statusCode != 202) {
      throw ApiException(response.statusCode, response.body);
    }
    return (jsonDecode(response.body) as Map<String, dynamic>)['task_id'];
  }

  // ---------------------------------------------------------------------------
  // Multi-track generation
  // ---------------------------------------------------------------------------

  Future<String> generateMultitrack(MultitrackParams params) async {
    final response = await _client.post(
      ApiConfig.uri('/api/generate/multitrack/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(params.toJson()),
    );

    if (response.statusCode != 202) {
      throw ApiException(response.statusCode, response.body);
    }
    return (jsonDecode(response.body) as Map<String, dynamic>)['task_id'];
  }

  // ---------------------------------------------------------------------------
  // Add track
  // ---------------------------------------------------------------------------

  Future<String> addTrack(
    AddTrackParams params, {
    required PickedFile promptMidi,
  }) async {
    return _multipartPost(
      '/api/generate/add-track/',
      params.toFormFields(),
      promptMidi,
    );
  }

  // ---------------------------------------------------------------------------
  // Replace track
  // ---------------------------------------------------------------------------

  Future<String> replaceTrack(
    ReplaceTrackParams params, {
    required PickedFile promptMidi,
  }) async {
    return _multipartPost(
      '/api/generate/replace-track/',
      params.toFormFields(),
      promptMidi,
    );
  }

  // ---------------------------------------------------------------------------
  // Task status
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getTaskStatus(String taskId) async {
    final response = await _client.get(
      ApiConfig.uri('/api/tasks/$taskId/'),
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------------
  // Download
  // ---------------------------------------------------------------------------

  Future<Uint8List> downloadFile(String downloadPath) async {
    final response = await _client.get(
      ApiConfig.uri(downloadPath),
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    return response.bodyBytes;
  }

  String getDownloadUrl(String downloadPath) {
    return ApiConfig.fullUrl(downloadPath);
  }

  // ---------------------------------------------------------------------------
  // MIDI to MP3 conversion
  // ---------------------------------------------------------------------------

  /// Convert a MIDI file to MP3 on the server.
  /// Returns the MP3 download URL path (e.g. '/api/download/{id}.mp3/').
  Future<String> convertMidi(PickedFile midiFile) async {
    final request = http.MultipartRequest('POST', ApiConfig.uri('/api/convert/'));
    request.files.add(
      http.MultipartFile.fromBytes('midi_file', midiFile.bytes, filename: midiFile.name),
    );

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    return (jsonDecode(response.body) as Map<String, dynamic>)['mp3_download_url'] as String;
  }

  /// Convert MIDI bytes to MP3 on the server.
  /// Returns the MP3 download URL path.
  Future<String> convertMidiBytes(Uint8List bytes) async {
    final request = http.MultipartRequest('POST', ApiConfig.uri('/api/convert/'));
    request.files.add(
      http.MultipartFile.fromBytes('midi_file', bytes, filename: 'input.mid'),
    );

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    return (jsonDecode(response.body) as Map<String, dynamic>)['mp3_download_url'] as String;
  }

  // ---------------------------------------------------------------------------
  // Cover
  // ---------------------------------------------------------------------------

  Future<String> cover(
    CoverParams params, {
    required PickedFile promptMidi,
  }) async {
    final request = http.MultipartRequest('POST', ApiConfig.uri('/api/generate/cover/'));
    request.fields.addAll(params.base.toFormFields());
    if (params.numTracks != null) {
      request.fields['num_tracks'] = params.numTracks.toString();
    }
    if (params.trackTypes != null) {
      for (final t in params.trackTypes!) {
        // DRF ListField accepts repeated field names
        request.fields['track_types'] = t;
      }
    }
    if (params.instruments != null) {
      for (final i in params.instruments!) {
        request.fields['instruments'] = i.toString();
      }
    }
    request.files.add(
      http.MultipartFile.fromBytes('prompt_midi', promptMidi.bytes, filename: promptMidi.name),
    );

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 202) {
      throw ApiException(response.statusCode, response.body);
    }
    return (jsonDecode(response.body) as Map<String, dynamic>)['task_id'];
  }

  // ---------------------------------------------------------------------------
  // Data download
  // ---------------------------------------------------------------------------

  Future<String> downloadTrainingData({String outputDir = 'midi_files'}) async {
    final response = await _client.post(
      ApiConfig.uri('/api/data/download/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'output_dir': outputDir}),
    );

    if (response.statusCode != 202) {
      throw ApiException(response.statusCode, response.body);
    }
    return (jsonDecode(response.body) as Map<String, dynamic>)['task_id'];
  }

  // ---------------------------------------------------------------------------
  // Data browse / scan
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> browseDirectory(
    String path, {
    List<String>? fileExtensions,
  }) async {
    final body = <String, dynamic>{'path': path};
    if (fileExtensions != null) {
      body['file_extensions'] = fileExtensions;
    }

    final response = await _client.post(
      ApiConfig.uri('/api/data/browse/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> scanMidiDir(String midiDir, {String? metadata}) async {
    final body = <String, dynamic>{'midi_dir': midiDir};
    if (metadata != null && metadata.isNotEmpty) {
      body['metadata'] = metadata;
    }

    final response = await _client.post(
      ApiConfig.uri('/api/data/scan/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> stageFiles(String sourceDir, List<String> files) async {
    final response = await _client.post(
      ApiConfig.uri('/api/data/stage/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'source_dir': sourceDir, 'files': files}),
    );

    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------------
  // Pretokenize
  // ---------------------------------------------------------------------------

  Future<String> pretokenize(Map<String, dynamic> params) async {
    final response = await _client.post(
      ApiConfig.uri('/api/pretokenize/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(params),
    );

    if (response.statusCode != 202) {
      throw ApiException(response.statusCode, response.body);
    }
    return (jsonDecode(response.body) as Map<String, dynamic>)['task_id'];
  }

  // ---------------------------------------------------------------------------
  // Diagnosis
  // ---------------------------------------------------------------------------

  Future<String> runDiagnosis(Map<String, dynamic> params) async {
    final response = await _client.post(
      ApiConfig.uri('/api/diagnosis/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(params),
    );

    if (response.statusCode != 202) {
      throw ApiException(response.statusCode, response.body);
    }
    return (jsonDecode(response.body) as Map<String, dynamic>)['task_id'];
  }

  // ---------------------------------------------------------------------------
  // Training
  // ---------------------------------------------------------------------------

  Future<String> startTraining(Map<String, dynamic> params) async {
    final response = await _client.post(
      ApiConfig.uri('/api/training/start/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(params),
    );

    if (response.statusCode != 202) {
      throw ApiException(response.statusCode, response.body);
    }
    return (jsonDecode(response.body) as Map<String, dynamic>)['task_id'];
  }

  Future<Map<String, dynamic>> getTrainingSummary({
    String checkpointDir = 'checkpoints',
  }) async {
    final response = await _client.get(
      ApiConfig.uri('/api/training/summary/')
          .replace(queryParameters: {'checkpoint_dir': checkpointDir}),
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAutoConfig(Map<String, dynamic> params) async {
    final response = await _client.post(
      ApiConfig.uri('/api/training/autotune/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(params),
    );

    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<String> _multipartPost(
    String path,
    Map<String, String> fields,
    PickedFile file,
  ) async {
    final request = http.MultipartRequest('POST', ApiConfig.uri(path));
    request.fields.addAll(fields);
    request.files.add(
      http.MultipartFile.fromBytes('prompt_midi', file.bytes, filename: file.name),
    );

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 202) {
      throw ApiException(response.statusCode, response.body);
    }
    return (jsonDecode(response.body) as Map<String, dynamic>)['task_id'];
  }

  void dispose() => _client.close();
}
