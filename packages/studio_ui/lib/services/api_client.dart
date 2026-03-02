import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../configuration/configuration_base.dart';
import '../http/diskrot_http_client.dart';
import '../models/model_capabilities.dart';
import '../models/task_status.dart';
import '../models/lyric_sheet.dart';
import '../models/workspace.dart';
import '../utils/filename_sanitizer.dart';
import '../widgets/visualizers/visualizer_type.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

class LoginResponse {
  LoginResponse({
    required this.idToken,
    required this.refreshToken,
    required this.email,
    required this.expiresIn,
  });

  final String idToken;
  final String refreshToken;
  final String email;
  final int expiresIn;
}

class ApiClient {
  ApiClient({required this.config, required this.httpClient});

  final Configuration config;
  final DiskRotHttpClient httpClient;

  /// Whether the active server backend is a remote peer.
  final ValueNotifier<bool> isRemote = ValueNotifier(false);

  /// The active visualizer style.  Loaded from settings at startup and
  /// updated when the user changes it in the Display settings tab.
  final ValueNotifier<VisualizerType> visualizerType =
      ValueNotifier(VisualizerType.creamdrop);

  /// All workspaces for the current user.
  final ValueNotifier<List<Workspace>> workspaces = ValueNotifier([]);

  /// The currently active workspace.
  final ValueNotifier<Workspace?> activeWorkspace = ValueNotifier(null);

  /// Reads the persisted `visualizer_type` setting and updates
  /// [visualizerType].  Safe to call early — silently falls back to the
  /// default on any error.
  Future<void> loadVisualizerSetting() async {
    try {
      final settings = await getSettings();
      visualizerType.value =
          VisualizerType.fromSettingsValue(settings['visualizer_type']);
    } catch (_) {
      // Keep default on error.
    }
  }

  /// Fetches server backends and updates [isRemote].
  Future<void> refreshRemoteStatus() async {
    try {
      final backends = await getServerBackends();
      final active =
          backends.where((b) => b['is_active'] == true).firstOrNull;
      isRemote.value = active != null;
    } catch (_) {
      // Leave current value unchanged on error.
    }
  }

  /// Login -- standalone raw HTTP call (pre-auth, no DiskRotHttpClient needed).
  Future<LoginResponse> login(String email, String password) async {
    final uri = config.buildUri('/v1/authentication/diskrot-login');
    final client = http.Client();
    try {
      final response = await client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        throw ApiException(
          response.statusCode,
          body['message'] as String? ?? 'Login failed',
        );
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return LoginResponse(
        idToken: body['idToken'] as String,
        refreshToken: body['refreshToken'] as String,
        email: body['email'] as String,
        expiresIn: _parseExpiresIn(body['expiresIn'] ?? body['expires_in']),
      );
    } finally {
      client.close();
    }
  }

  /// Fetch the server-assigned external user ID.
  Future<String> getUserId() async {
    final response = await httpClient.get(endpoint: '/users/me');

    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'Failed to get user ID');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['user_id'] as String;
  }

  Future<String> submitTask(Map<String, dynamic> taskBody) async {
    final response = await httpClient.post(
      endpoint: '/audio/generate',
      data: taskBody,
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        response.statusCode,
        body['message'] as String? ?? 'Task submission failed',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['task_id'] as String;
  }

  Future<TaskStatus> getTaskStatus(String taskId) async {
    final response = await httpClient.get(endpoint: '/audio/tasks/$taskId');

    if (response.statusCode == 404) {
      throw ApiException(404, 'Task not found');
    }

    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'Failed to get task status');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return TaskStatus.fromJson(body);
  }

  Future<({List<TaskStatus> songs, String? nextCursor, bool hasMore})>
  getSongs({
    String? cursor,
    int limit = 20,
    int? rating,
    String? sort,
    String? workspaceId,
    String? lyricsSearch,
  }) async {
    final query = <String, dynamic>{'limit': '$limit'};
    if (cursor != null) query['cursor'] = cursor;
    if (rating != null) query['rating'] = '$rating';
    if (sort != null) query['sort'] = sort;
    if (workspaceId != null) query['workspace_id'] = workspaceId;
    if (lyricsSearch != null) query['lyrics_search'] = lyricsSearch;

    final response = await httpClient.get(
      endpoint: '/audio/songs',
      query: query,
    );

    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'Failed to get songs');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (body['data'] as List<dynamic>?) ?? [];
    final songs = data
        .map((e) => TaskStatus.fromSongJson(e as Map<String, dynamic>))
        .toList();

    return (
      songs: songs,
      nextCursor: body['nextCursor'] as String?,
      hasMore: body['hasMore'] as bool? ?? false,
    );
  }

  Future<Map<String, dynamic>> healthCheck() async {
    final response = await httpClient.get(endpoint: '/audio/health');

    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'Health check failed');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Build the full URL for the server-side song download endpoint.
  String songDownloadUrl(String taskId) {
    return config.buildUri('/v1/audio/songs/$taskId/download').toString();
  }

  /// Download audio bytes from an internal API URL via the authenticated client.
  Future<Uint8List> downloadAudioBytes(String fileUrl) async {
    final uri = Uri.parse(fileUrl);
    final pathSegments = uri.pathSegments;
    final versionIndex = pathSegments.indexOf('v1');
    final endpoint = versionIndex >= 0
        ? '/${pathSegments.sublist(versionIndex + 1).join('/')}${uri.hasQuery ? '?${uri.query}' : ''}'
        : uri.path;
    final response = await httpClient.get(endpoint: endpoint);
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'Failed to download audio');
    }
    return response.bodyBytes;
  }

  // ---------------------------------------------------------------------------
  // Upload
  // ---------------------------------------------------------------------------

  /// Response from [createUpload].
  /// Contains the GCS resumable session URL and metadata needed for finalize.

  /// Initialise a resumable upload session on the server.
  ///
  /// Returns the JSON body with `uploadUrl`, `objectName`, `id`, `token`,
  /// `size`, and `contentType`.
  Future<Map<String, dynamic>> createUpload({
    required String filename,
    required String contentType,
    required int size,
  }) async {
    final response = await httpClient.post(
      endpoint: '/audio/upload',
      data: {'filename': filename, 'contentType': contentType, 'size': size},
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        response.statusCode,
        body['message'] as String? ?? 'Failed to create upload',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Finalize (or continue) a resumable upload by sending bytes through the
  /// server, which proxies them to GCS.
  ///
  /// Returns the raw [http.Response] so the caller can inspect the status code
  /// (308 = more chunks needed, 2xx = done).
  Future<http.Response> finalizeUpload({
    required String sessionUrl,
    required String contentType,
    required String contentRange,
    required String fileId,
    required Uint8List bytes,
  }) async {
    return httpClient.putBytes(
      endpoint: '/audio/upload/finalize',
      bytes: bytes,
      headers: {
        'X-Session-Url': sessionUrl,
        'X-Content-Type': contentType,
        'X-Content-Range': contentRange,
        'Diskrot-File-Id': fileId,
      },
    );
  }

  Future<void> updateSong({
    required String taskId,
    String? title,
    String? lyrics,
    int? rating,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'lyrics': lyrics,
      'rating': rating,
    };

    final response = await httpClient.patch(
      endpoint: '/audio/songs/$taskId',
      data: body,
    );

    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'Failed to update song');
    }
  }

  Future<void> moveSong({
    required String taskId,
    required String workspaceId,
  }) async {
    final response = await httpClient.patch(
      endpoint: '/audio/songs/$taskId',
      data: {'workspace_id': workspaceId},
    );

    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'Failed to move song');
    }
  }

  Future<void> deleteSong({required String taskId}) async {
    final response = await httpClient.delete(endpoint: '/audio/songs/$taskId');

    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'Failed to delete song');
    }
  }

  Future<int> batchDeleteSongs({required List<String> taskIds}) async {
    final response = await httpClient.post(
      endpoint: '/audio/songs/batch-delete',
      data: {'task_ids': taskIds},
    );

    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'Failed to batch delete songs');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['deleted'] as int? ?? 0;
  }

  Future<TaskStatus> getSongDetails(String taskId) async {
    final response = await httpClient.get(endpoint: '/audio/songs/$taskId');

    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'Failed to get song details');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return TaskStatus.fromSongJson(body);
  }

  // ---------------------------------------------------------------------------
  // Logs
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getLogs() async {
    final response = await httpClient.get(endpoint: '/logs');
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'Failed to get logs');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['data'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  Future<Map<String, String>> getSettings() async {
    final response = await httpClient.get(
      endpoint: '/settings',
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'Failed to get settings');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body.map((k, v) => MapEntry(k, v as String));
  }

  Future<void> updateSettings(Map<String, String> settings) async {
    final response = await httpClient.put(
      endpoint: '/settings',
      data: settings,
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        response.statusCode,
        body['message'] as String? ?? 'Failed to update settings',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Server Backends
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getServerBackends() async {
    final response = await httpClient.get(
      endpoint: '/server-backends',
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'Failed to get server backends');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['data'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createServerBackend({
    required String name,
    required String apiHost,
    required bool secure,
  }) async {
    final response = await httpClient.post(
      endpoint: '/server-backends',
      data: {'name': name, 'api_host': apiHost, 'secure': secure},
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        response.statusCode,
        body['message'] as String? ?? 'Failed to create server backend',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> updateServerBackend({
    required String id,
    String? name,
    String? apiHost,
    bool? secure,
  }) async {
    final response = await httpClient.put(
      endpoint: '/server-backends/$id',
      data: {
        'name': ?name,
        'api_host': ?apiHost,
        'secure': ?secure,
      },
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        response.statusCode,
        body['message'] as String? ?? 'Failed to update server backend',
      );
    }
  }

  Future<void> deleteServerBackend(String id) async {
    final response = await httpClient.delete(
      endpoint: '/server-backends/$id',
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        response.statusCode,
        body['message'] as String? ?? 'Failed to delete server backend',
      );
    }
  }

  Future<void> activateServerBackend(String id) async {
    final response = await httpClient.put(
      endpoint: '/server-backends/$id/activate',
      data: {},
    );
    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode,
        'Failed to activate server backend',
      );
    }
  }

  /// Test whether a remote host is healthy before adding it as a backend.
  /// Returns `true` if the host responds to the health endpoint.
  static Future<bool> testRemoteHealth({
    required String host,
    required bool secure,
  }) async {
    final uri = secure
        ? Uri.https(host, 'v1/health/status')
        : Uri.http(host, 'v1/health/status');
    final client = http.Client();
    try {
      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Peers
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getPeers() async {
    final response = await httpClient.get(endpoint: '/peers');
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'Failed to get peers');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['data'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<void> blockPeer(String id) async {
    final response = await httpClient.put(
      endpoint: '/peers/$id/block',
      data: {},
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'Failed to block peer');
    }
  }

  Future<void> unblockPeer(String id) async {
    final response = await httpClient.put(
      endpoint: '/peers/$id/unblock',
      data: {},
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'Failed to unblock peer');
    }
  }

  // ---------------------------------------------------------------------------
  // Workspaces
  // ---------------------------------------------------------------------------

  Future<List<Workspace>> getWorkspaces() async {
    final response = await httpClient.get(endpoint: '/workspaces');
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'Failed to get workspaces');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['data'] as List<dynamic>)
        .map((e) => Workspace.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Workspace> createWorkspace(String name) async {
    final response = await httpClient.post(
      endpoint: '/workspaces',
      data: {'name': name},
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        response.statusCode,
        body['message'] as String? ?? 'Failed to create workspace',
      );
    }
    return Workspace.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> renameWorkspace(String id, String name) async {
    final response = await httpClient.put(
      endpoint: '/workspaces/$id',
      data: {'name': name},
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'Failed to rename workspace');
    }
  }

  Future<void> deleteWorkspace(String id) async {
    final response = await httpClient.delete(endpoint: '/workspaces/$id');
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        response.statusCode,
        body['message'] as String? ?? 'Failed to delete workspace',
      );
    }
  }

  /// Loads workspaces from the backend and sets the active one.
  Future<void> loadWorkspaces() async {
    try {
      final list = await getWorkspaces();
      workspaces.value = list;
      if (activeWorkspace.value == null && list.isNotEmpty) {
        activeWorkspace.value =
            list.firstWhere((w) => w.isDefault, orElse: () => list.first);
      }
    } catch (_) {
      // Best-effort — workspaces load silently on failure.
    }
  }

  // ---------------------------------------------------------------------------
  // Lyric Book
  // ---------------------------------------------------------------------------

  Future<List<LyricSheet>> getLyricSheets() async {
    final response = await httpClient.get(endpoint: '/lyric-book');
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'Failed to load lyric sheets');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = body['data'] as List<dynamic>;
    return list
        .map((e) => LyricSheet.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<LyricSheet> createLyricSheet({
    required String title,
    required String content,
  }) async {
    final response = await httpClient.post(
      endpoint: '/lyric-book',
      data: {'title': title, 'content': content},
    );
    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode,
        'Failed to create lyric sheet',
      );
    }
    return LyricSheet.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<Map<String, dynamic>> getLyricSheetDetail(String id) async {
    final response = await httpClient.get(endpoint: '/lyric-book/$id');
    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode,
        'Failed to load lyric sheet',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> updateLyricSheet(
    String id, {
    String? title,
    String? content,
  }) async {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (content != null) data['content'] = content;
    final response = await httpClient.patch(
      endpoint: '/lyric-book/$id',
      data: data,
    );
    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode,
        'Failed to update lyric sheet',
      );
    }
  }

  Future<void> deleteLyricSheet(String id) async {
    final response = await httpClient.delete(endpoint: '/lyric-book/$id');
    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode,
        'Failed to delete lyric sheet',
      );
    }
  }

  Future<List<LyricSheet>> searchLyricSheets(String query) async {
    final response = await httpClient.get(
      endpoint: '/lyric-book/search?q=${Uri.encodeQueryComponent(query)}',
    );
    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode,
        'Failed to search lyric sheets',
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = body['data'] as List<dynamic>;
    return list
        .map((e) => LyricSheet.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> linkSongToLyricSheet(String taskId, String? lyricSheetId) async {
    final data = <String, dynamic>{'lyric_sheet_id': lyricSheetId};
    final response = await httpClient.patch(
      endpoint: '/audio/songs/$taskId',
      data: data,
    );
    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode,
        'Failed to link song to lyric sheet',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Text generation
  // ---------------------------------------------------------------------------

  Future<String> generateLyrics(
    String model,
    String description, {
    String? audioModel,
  }) async {
    final response = await httpClient.post(
      endpoint: '/text/lyrics',
      data: {
        'model': model,
        'description': description,
        'audio_model': ?audioModel,
      },
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        response.statusCode,
        body['message'] as String? ?? 'Failed to generate lyrics',
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['lyrics'] as String;
  }

  Future<String> generatePrompt(
    String model,
    String description, {
    String? audioModel,
  }) async {
    final response = await httpClient.post(
      endpoint: '/text/prompt',
      data: {
        'model': model,
        'description': description,
        'audio_model': ?audioModel,
      },
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        response.statusCode,
        body['message'] as String? ?? 'Failed to generate prompt',
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['prompt'] as String;
  }

  // ---------------------------------------------------------------------------
  // Model defaults
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getModelDefaults(String model) async {
    final response = await httpClient.get(endpoint: '/audio/$model/defaults');
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'Failed to get model defaults');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['data'] as Map<String, dynamic>?) ?? body;
  }

  // ---------------------------------------------------------------------------
  // Model capabilities
  // ---------------------------------------------------------------------------

  Future<ModelCapabilities> getModelCapabilities(String model) async {
    final response =
        await httpClient.get(endpoint: '/audio/$model/capabilities');
    if (response.statusCode != 200) {
      throw ApiException(
          response.statusCode, 'Failed to get model capabilities');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (body['data'] as Map<String, dynamic>?) ?? body;
    return ModelCapabilities.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // LoRA
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getLoraList() async {
    final response = await httpClient.get(endpoint: '/audio/lora/list');
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'Failed to list LoRAs');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    // The endpoint wraps the payload in a `data` key – unwrap it.
    final data = (body['data'] as Map<String, dynamic>?) ?? body;
    return (data['loras'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
        [];
  }

  Future<Map<String, dynamic>> getLoraStatus() async {
    final response = await httpClient.get(endpoint: '/audio/lora/status');
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'Failed to get LoRA status');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    // The Modal endpoint wraps the payload in a `data` key – unwrap it.
    return (body['data'] as Map<String, dynamic>?) ?? body;
  }

  Future<Map<String, dynamic>> loadLora(
    String loraPath, {
    String? adapterName,
  }) async {
    final response = await httpClient.post(
      endpoint: '/audio/lora/load',
      data: {'lora_path': loraPath, 'adapter_name': ?adapterName},
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        response.statusCode,
        body['message'] as String? ?? 'Failed to load LoRA',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> unloadLora() async {
    final response = await httpClient.post(
      endpoint: '/audio/lora/unload',
      data: {},
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'Failed to unload LoRA');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> toggleLora(bool useLora) async {
    final response = await httpClient.post(
      endpoint: '/audio/lora/toggle',
      data: {'use_lora': useLora},
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'Failed to toggle LoRA');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setLoraScale(
    double scale, {
    String? adapterName,
  }) async {
    final response = await httpClient.post(
      endpoint: '/audio/lora/scale',
      data: {'scale': scale, 'adapter_name': ?adapterName},
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'Failed to set LoRA scale');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------------
  // Training
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> loadTensorInfo(String tensorDir) async {
    final response = await httpClient.post(
      endpoint: '/training/load_tensor_info',
      data: {'tensor_dir': tensorDir},
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        response.statusCode,
        body['message'] as String? ?? 'Failed to load tensor info',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> startTraining(
    Map<String, dynamic> params,
  ) async {
    final response = await httpClient.post(
      endpoint: '/training/start',
      data: params,
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        response.statusCode,
        body['message'] as String? ?? 'Failed to start training',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> startLoKRTraining(
    Map<String, dynamic> params,
  ) async {
    final response = await httpClient.post(
      endpoint: '/training/start_lokr',
      data: params,
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        response.statusCode,
        body['message'] as String? ?? 'Failed to start LoKR training',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getTrainingStatus() async {
    final response = await httpClient.get(endpoint: '/training/status');
    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode,
        'Failed to get training status',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> stopTraining() async {
    final response = await httpClient.post(
      endpoint: '/training/stop',
      data: {},
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'Failed to stop training');
    }
  }

  Future<Map<String, dynamic>> exportLora({
    required String exportPath,
    required String loraOutputDir,
  }) async {
    final response = await httpClient.post(
      endpoint: '/training/export',
      data: {'export_path': exportPath, 'lora_output_dir': loraOutputDir},
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        response.statusCode,
        body['message'] as String? ?? 'Failed to export LoRA',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------------
  // Dataset
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> uploadDatasetZip({
    required Uint8List bytes,
    required String filename,
    String datasetName = 'my_lora_dataset',
    String customTag = '',
    String tagPosition = 'replace',
    bool allInstrumental = true,
  }) async {
    final response = await httpClient.postMultipart(
      endpoint: '/dataset/upload',
      bytes: bytes,
      filename: sanitizeFilename(filename),
      mimeType: 'application/zip',
      fields: {
        'dataset_name': datasetName,
        'custom_tag': customTag,
        'tag_position': tagPosition,
        'all_instrumental': allInstrumental.toString(),
      },
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        response.statusCode,
        body['error'] as String? ??
            body['message'] as String? ??
            'Failed to upload dataset zip',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> loadDataset(String datasetPath) async {
    final response = await httpClient.post(
      endpoint: '/dataset/load',
      data: {'dataset_path': datasetPath},
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        response.statusCode,
        body['error'] as String? ??
            body['message'] as String? ??
            'Failed to load dataset',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> startAutoLabel(
    Map<String, dynamic> params,
  ) async {
    final response = await httpClient.post(
      endpoint: '/dataset/auto_label_async',
      data: params,
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        response.statusCode,
        body['error'] as String? ??
            body['message'] as String? ??
            'Failed to start auto-labeling',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAutoLabelStatus() async {
    final response = await httpClient.get(
      endpoint: '/dataset/auto_label_status',
    );
    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode,
        'Failed to get auto-label status',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAutoLabelTaskStatus(String taskId) async {
    final response = await httpClient.get(
      endpoint: '/dataset/auto_label_status/$taskId',
    );
    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode,
        'Failed to get auto-label task status',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> saveDataset(
    Map<String, dynamic> params,
  ) async {
    final response = await httpClient.post(
      endpoint: '/dataset/save',
      data: params,
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        response.statusCode,
        body['error'] as String? ??
            body['message'] as String? ??
            'Failed to save dataset',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> startPreprocess(
    Map<String, dynamic> params,
  ) async {
    final response = await httpClient.post(
      endpoint: '/dataset/preprocess_async',
      data: params,
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        response.statusCode,
        body['error'] as String? ??
            body['message'] as String? ??
            'Failed to start preprocessing',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getPreprocessStatus() async {
    final response = await httpClient.get(
      endpoint: '/dataset/preprocess_status',
    );
    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode,
        'Failed to get preprocess status',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getPreprocessTaskStatus(String taskId) async {
    final response = await httpClient.get(
      endpoint: '/dataset/preprocess_status/$taskId',
    );
    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode,
        'Failed to get preprocess task status',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getDatasetSamples() async {
    final response = await httpClient.get(endpoint: '/dataset/samples');
    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode,
        'Failed to get dataset samples',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateDatasetSample(
    int idx,
    Map<String, dynamic> data,
  ) async {
    final response = await httpClient.put(
      endpoint: '/dataset/sample/$idx',
      data: data,
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        response.statusCode,
        body['error'] as String? ??
            body['message'] as String? ??
            'Failed to update dataset sample',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------------
  // Browse directories (local to the backend server)
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> browseDirectory(
    String path, {
    List<String>? fileExtensions,
  }) async {
    final data = <String, dynamic>{'path': path};
    if (fileExtensions != null) data['file_extensions'] = fileExtensions;

    final response = await httpClient.post(
      endpoint: '/browse',
      data: data,
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        response.statusCode,
        body['message'] as String? ?? 'Failed to browse directory',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  int _parseExpiresIn(dynamic raw) {
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw) ?? 3600;
    return 3600;
  }
}
