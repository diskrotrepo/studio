import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:studio_backend/src/audio/audio_client.dart';
import 'package:studio_backend/src/audio/audio_generation_task_repository.dart';
import 'package:studio_backend/src/audio/audio_model_client.dart';
import 'package:studio_backend/src/audio/dto/audio_generate_request.dart';
import 'package:studio_backend/src/cache/cache.dart';
import 'package:studio_backend/src/database/postgres.dart';
import 'package:studio_backend/src/logger/logger.dart' show logger;
import 'package:studio_backend/src/storage/cloud_storage.dart';
import 'package:studio_backend/src/utils/cursor_pagination.dart';
import 'package:studio_backend/src/utils/exceptions.dart';
import 'package:studio_backend/src/utils/parse_json.dart';
import 'package:studio_backend/src/utils/shelf_helper.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

part 'audio_service.g.dart';

class _TaskStatus {
  _TaskStatus({
    required this.taskId,
    required this.status,
    required this.taskType,
    this.model,
    this.result,
    this.error,
  });

  factory _TaskStatus.fromJson(Map<String, dynamic> json) => _TaskStatus(
    taskId: json['task_id'] as String,
    status: json['status'] as String,
    taskType: json['task_type'] as String? ?? 'unknown',
    model: json['model'] as String?,
    result: json['result'] as Map<String, dynamic>?,
    error: json['error'] as String?,
  );

  final String taskId;
  final String status;
  final String taskType;
  final String? model;
  final Map<String, dynamic>? result;
  final String? error;

  Map<String, dynamic> toJson() => {
    'task_id': taskId,
    'status': status,
    'task_type': taskType,
    if (model != null) 'model': model,
    if (result != null) 'result': result,
    if (error != null) 'error': error,
  };
}

class AudioService {
  AudioService({
    required AudioClient audioClient,
    required Cache cache,
    required String studioBucket,
    required AudioGenerationTaskRepository audioGenerationTaskRepository,
    required CloudStorage cloudStorage,
  }) : _client = audioClient,
       _cache = cache,
       _studioBucket = studioBucket,
       _taskRepository = audioGenerationTaskRepository,
       _cloudStorage = cloudStorage;

  final AudioClient _client;
  final Cache _cache;
  final String _studioBucket;
  final AudioGenerationTaskRepository _taskRepository;
  final CloudStorage _cloudStorage;

  static const _taskTtl = Duration(hours: 1);
  static const _cachePrefix = 'audio_task:';
  static const _maxUploadBytes = 500 * 1024 * 1024; // 500 MB

  Router get router => _$AudioServiceRouter(this);

  // -----------------------------------------------------------------------
  // Health
  // -----------------------------------------------------------------------

  @Route.get('/health')
  Future<Response> health(Request request) async {
    final statuses = <String, bool>{};
    for (final model in _client.models) {
      statuses[model] = await _client.healthCheck(model);
    }
    final allOk = statuses.values.every((v) => v);
    return jsonOk({'status': allOk ? 'ok' : 'degraded', 'models': statuses});
  }

  // -----------------------------------------------------------------------
  // Model defaults
  // -----------------------------------------------------------------------

  @Route.get('/<model>/defaults')
  Future<Response> modelDefaults(Request request, String model) async {
    final defs = _client.getDefaults(model);
    if (defs == null) {
      return jsonErr(404, {
        'message': 'Unknown model: $model',
        'available_models': _client.models.toList(),
      });
    }
    return jsonOk({'data': defs});
  }

  // -----------------------------------------------------------------------
  // Capabilities
  // -----------------------------------------------------------------------

  @Route.get('/<model>/capabilities')
  Future<Response> modelCapabilities(Request request, String model) async {
    final caps = _client.getCapabilities(model);
    if (caps == null) {
      return jsonErr(404, {
        'message': 'Unknown model: $model',
        'available_models': _client.models.toList(),
      });
    }
    return jsonOk({'data': caps});
  }

  // -----------------------------------------------------------------------
  // Songs (completed generations for the authenticated user)
  // -----------------------------------------------------------------------

  @Route.get('/songs')
  Future<Response> getSongs(Request request) async {
    if (request.isAnonymous) {
      return Response.unauthorized(
        jsonEncode({'message': 'This action requires authentication'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final query = request.url.queryParameters;

    try {
      final cursor = parseCursor(query);
      final limit = parseLimit(query);
      final ratingStr = query['rating'];
      final int? rating = ratingStr != null ? int.tryParse(ratingStr) : null;
      final sort = query['sort'] ?? 'newest';
      final descending = sort != 'oldest';
      final workspaceId = query['workspace_id'];
      final lyricsSearch = query['lyrics_search'];

      final (songs, hasMore) = (lyricsSearch != null && lyricsSearch.isNotEmpty)
          ? await _taskRepository.searchSongsByLyrics(
              userId: request.userId,
              query: lyricsSearch,
              limit: limit,
              cursor: cursor,
              descending: descending,
              workspaceId: workspaceId,
            )
          : await _taskRepository.getSongsByUserId(
              userId: request.userId,
              limit: limit,
              cursor: cursor,
              rating: rating,
              descending: descending,
              workspaceId: workspaceId,
            );

      final nextCursor = hasMore && songs.isNotEmpty
          ? encodeCursor(
              songs.last.createdAt.asDateTime ?? DateTime.now(),
              songs.last.id,
            )
          : null;

      return jsonOk({
        'data': songs
            .map(
              (s) => {
                'id': s.id,
                'task_id': s.taskId,
                'task_type': s.taskType,
                'model': s.model,
                'prompt': s.prompt,
                'lyrics': s.lyrics,
                'status': s.status,
                'title': s.title,
                'rating': s.rating,
                'workspace_id': s.workspaceId,
                'lyric_sheet_id': s.lyricSheetId,
                'result': s.result != null ? jsonDecode(s.result!) : null,
                'created_at': s.createdAt.asDateTime?.toIso8601String(),
                'completed_at': s.completedAt.asDateTime?.toIso8601String(),
              },
            )
            .toList(),
        'nextCursor': nextCursor,
        'hasMore': hasMore,
      });
    } on InvalidCursorException catch (e) {
      return jsonErr(400, {'message': e.message});
    }
  }

  @Route.get('/songs/<songId>')
  Future<Response> getSong(Request request, String songId) async {
    if (request.isAnonymous) {
      return Response.unauthorized(
        jsonEncode({'message': 'This action requires authentication'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final song = await _taskRepository.getSongByTaskId(
      userId: request.userId,
      taskId: songId,
    );

    if (song == null) {
      return jsonErr(404, {'message': 'Song not found'});
    }

    return jsonOk({
      'id': song.id,
      'task_id': song.taskId,
      'task_type': song.taskType,
      'model': song.model,
      'prompt': song.prompt,
      'lyrics': song.lyrics,
      'status': song.status,
      'title': song.title,
      'rating': song.rating,
      'lyric_sheet_id': song.lyricSheetId,
      'result': song.result != null ? jsonDecode(song.result!) : null,
      'created_at': song.createdAt.asDateTime?.toIso8601String(),
      'completed_at': song.completedAt.asDateTime?.toIso8601String(),
      'parameters': {
        if (song.temperature != null) 'temperature': song.temperature,
        if (song.guidanceScale != null) 'guidance_scale': song.guidanceScale,
        if (song.inferenceSteps != null) 'inference_steps': song.inferenceSteps,
        if (song.audioDuration != null) 'audio_duration': song.audioDuration,
        if (song.batchSize != null) 'batch_size': song.batchSize,
        if (song.cfgScale != null) 'cfg_scale': song.cfgScale,
        if (song.topP != null) 'top_p': song.topP,
        if (song.repetitionPenalty != null)
          'repetition_penalty': song.repetitionPenalty,
        if (song.shift != null) 'shift': song.shift,
        if (song.cfgIntervalStart != null)
          'cfg_interval_start': song.cfgIntervalStart,
        if (song.cfgIntervalEnd != null)
          'cfg_interval_end': song.cfgIntervalEnd,
        if (song.thinking != null) 'thinking': song.thinking,
        if (song.constrainedDecoding != null)
          'constrained_decoding': song.constrainedDecoding,
        if (song.useRandomSeed != null) 'use_random_seed': song.useRandomSeed,
        if (song.inferMethod != null) 'infer_method': song.inferMethod,
        if (song.timeSignature != null) 'time_signature': song.timeSignature,
        if (song.audioFormat != null) 'audio_format': song.audioFormat,
        if (song.negativePrompt != null)
          'negative_prompt': song.negativePrompt,
      },
    });
  }

  @Route.get('/songs/<songId>/download')
  Future<Response> downloadSong(Request request, String songId) async {
    if (request.isAnonymous) {
      return Response.unauthorized(
        jsonEncode({'message': 'This action requires authentication'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final song = await _taskRepository.getSongByTaskId(
      userId: request.userId,
      taskId: songId,
    );

    if (song == null) {
      return jsonErr(404, {'message': 'Song not found'});
    }

    if (song.result == null) {
      return jsonErr(404, {'message': 'No audio file available'});
    }

    final result = jsonDecode(song.result!) as Map<String, dynamic>;

    // Try local storage (bucket + object written by upload or generation).
    final bucket = result['bucket'] as String?;
    final object = result['object'] as String?;
    if (bucket != null && object != null) {
      try {
        final bytes = await _cloudStorage.bucket(bucket).readBinary(object);
        final filename = object.contains('/')
            ? object.substring(object.lastIndexOf('/') + 1)
            : object;
        return Response.ok(
          bytes,
          headers: {
            'Content-Type': 'audio/mpeg',
            'Content-Disposition': 'attachment; filename="$filename"',
            'Content-Length': '${bytes.length}',
          },
        );
      } catch (e) {
        logger.e(message: 'Failed to read local file for $songId', error: e);
        return jsonErr(500, {'message': 'Failed to read audio file'});
      }
    }

    // Fall back to proxying the file URL returned by the model.
    final results = result['results'] as List<dynamic>?;
    if (results != null && results.isNotEmpty) {
      final fileUrl =
          (results.first as Map<String, dynamic>)['file'] as String?;
      if (fileUrl != null) {
        try {
          // Resolve relative URLs (e.g. songs stored before the client-side
          // fix was applied) against the model's base URL.
          final resolvedUrl = Uri.tryParse(fileUrl)?.hasAuthority == true
              ? fileUrl
              : '${_client.baseUrlFor(song.model) ?? ''}$fileUrl';
          final bytes = await _fetchUrl(resolvedUrl);
          final filename =
              Uri.tryParse(resolvedUrl)?.pathSegments.lastOrNull ??
              '$songId.mp3';
          return Response.ok(
            bytes,
            headers: {
              'Content-Type': 'audio/mpeg',
              'Content-Disposition': 'attachment; filename="$filename"',
              'Content-Length': '${bytes.length}',
            },
          );
        } catch (e) {
          logger.e(
            message: 'Failed to proxy audio for $songId from $fileUrl',
            error: e,
          );
          return jsonErr(500, {'message': 'Failed to download audio'});
        }
      }
    }

    return jsonErr(404, {'message': 'Audio file not found'});
  }

  Future<Uint8List> _fetchUrl(String url) async {
    final client = http.Client();
    try {
      final response = await client.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw StateError('HTTP ${response.statusCode} downloading $url');
      }
      return response.bodyBytes;
    } finally {
      client.close();
    }
  }

  @Route('PATCH', '/songs/<songId>')
  Future<Response> updateSong(Request request, String songId) async {
    if (request.isAnonymous) {
      return Response.unauthorized(
        jsonEncode({'message': 'This action requires authentication'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    if (extractContentType(request.headers)?.contains('application/json') !=
        true) {
      return jsonErr(400, {'message': 'application/json expected'});
    }

    final body =
        jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final title = body['title'] as String?;
    final rating = body['rating'] as int?;
    final workspaceId = body['workspace_id'] as String?;
    final hasLyricSheetId = body.containsKey('lyric_sheet_id');
    final lyricSheetId = body['lyric_sheet_id'] as String?;

    if (title == null &&
        rating == null &&
        workspaceId == null &&
        !hasLyricSheetId) {
      return jsonErr(
        400,
        {
          'message':
              'title, rating, workspace_id, or lyric_sheet_id is required'
        },
      );
    }

    if (title != null) {
      await _taskRepository.updateTitle(
        taskId: songId,
        userId: request.userId,
        title: title,
      );
    }

    if (rating != null) {
      await _taskRepository.updateRating(
        taskId: songId,
        userId: request.userId,
        rating: rating == 0 ? null : rating,
      );
    }

    if (workspaceId != null) {
      await _taskRepository.updateWorkspace(
        taskId: songId,
        userId: request.userId,
        workspaceId: workspaceId,
      );
    }

    if (hasLyricSheetId) {
      await _taskRepository.updateLyricSheetId(
        taskId: songId,
        userId: request.userId,
        lyricSheetId: lyricSheetId,
      );
    }

    return jsonOk({'ok': true});
  }

  @Route.delete('/songs/<songId>')
  Future<Response> deleteSong(Request request, String songId) async {
    if (request.isAnonymous) {
      return Response.unauthorized(
        jsonEncode({'message': 'This action requires authentication'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final song = await _taskRepository.getSongByTaskId(
      userId: request.userId,
      taskId: songId,
    );

    if (song == null) {
      return jsonErr(404, {'message': 'Song not found'});
    }

    await _taskRepository.deleteSong(taskId: songId, userId: request.userId);

    // Best-effort local storage cleanup.
    if (song.result != null) {
      try {
        final result = jsonDecode(song.result!) as Map<String, dynamic>;
        final bucket = result['bucket'] as String?;
        final object = result['object'] as String?;
        if (bucket != null && object != null) {
          await _cloudStorage.bucket(bucket).delete(object);
        }
      } catch (e) {
        logger.e(
          message: 'Failed to clean up local file for song $songId',
          error: e,
        );
      }
    }

    return jsonOk({'ok': true});
  }

  @Route.post('/songs/batch-delete')
  Future<Response> batchDeleteSongs(Request request) async {
    if (request.isAnonymous) {
      return Response.unauthorized(
        jsonEncode({'message': 'This action requires authentication'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    if (extractContentType(request.headers)?.contains('application/json') !=
        true) {
      return jsonErr(400, {'message': 'application/json expected'});
    }

    final body =
        jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final taskIds = (body['task_ids'] as List<dynamic>?)?.cast<String>();

    if (taskIds == null || taskIds.isEmpty) {
      return jsonErr(400, {
        'message': 'task_ids is required and must be non-empty',
      });
    }

    if (taskIds.length > 100) {
      return jsonErr(400, {
        'message': 'Maximum 100 songs can be deleted at once',
      });
    }

    // Fetch songs first for storage cleanup.
    final songs = await _taskRepository.getSongsByTaskIds(
      taskIds: taskIds,
      userId: request.userId,
    );

    final deletedCount = await _taskRepository.deleteSongs(
      taskIds: taskIds,
      userId: request.userId,
    );

    // Best-effort storage cleanup.
    for (final song in songs) {
      if (song.result != null) {
        try {
          final result = jsonDecode(song.result!) as Map<String, dynamic>;
          final bucket = result['bucket'] as String?;
          final object = result['object'] as String?;
          if (bucket != null && object != null) {
            await _cloudStorage.bucket(bucket).delete(object);
          }
        } catch (e) {
          logger.e(
            message: 'Batch delete: failed to clean up file for ${song.taskId}',
            error: e,
          );
        }
      }
    }

    return jsonOk({'ok': true, 'deleted': deletedCount});
  }

  // -----------------------------------------------------------------------
  // Upload
  // -----------------------------------------------------------------------

  @Route.post('/upload')
  Future<Response> createUpload(Request request) async {
    if (request.isAnonymous) {
      return Response.unauthorized(
        jsonEncode({'message': 'This action requires authentication'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    if (extractContentType(request.headers)?.contains('application/json') !=
        true) {
      return jsonErr(400, {'message': 'application/json expected'});
    }

    final body =
        jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final filename = (body['filename'] as String?)?.trim();
    final contentType = (body['contentType'] as String?)?.trim();
    final totalBytes = (body['size'] as num?)?.toInt();

    if (filename == null ||
        filename.isEmpty ||
        contentType == null ||
        contentType.isEmpty ||
        totalBytes == null ||
        totalBytes <= 0) {
      return jsonErr(400, {
        'message': 'filename, contentType, and size are required',
      });
    }

    if (totalBytes > _maxUploadBytes) {
      return jsonErr(413, {
        'message':
            'File exceeds maximum size of ${_maxUploadBytes ~/ (1024 * 1024)} MB',
      });
    }

    final id = const Uuid().v4();
    final ext = filename.contains('.')
        ? filename.substring(filename.lastIndexOf('.') + 1)
        : 'wav';
    final objectName = '${request.userId}/uploads/$id.$ext';

    // Cache session metadata so finalizeUpload can look up objectName by id.
    await _cache.set(
      key: 'upload_session:$id',
      value: jsonEncode({'objectName': objectName, 'contentType': contentType}),
      ttl: const Duration(hours: 2),
    );

    return jsonOk({
      'objectName': objectName,
      'uploadUrl': id,
      'id': id,
      'size': totalBytes,
      'contentType': contentType,
    });
  }

  @Route.put('/upload/finalize')
  Future<Response> finalizeUpload(Request request) async {
    if (request.isAnonymous) {
      return Response.unauthorized(
        jsonEncode({'message': 'This action requires authentication'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final uploadId = request.headers['Diskrot-File-Id'] ?? '';
    if (uploadId.isEmpty) {
      return jsonErr(400, {'message': 'Diskrot-File-Id is required'});
    }

    final sessionRaw = await _cache.get(key: 'upload_session:$uploadId');
    if (sessionRaw == null) {
      return jsonErr(400, {'message': 'Upload session not found or expired'});
    }

    final session =
        jsonDecode(sessionRaw as String) as Map<String, dynamic>;
    final objectName = session['objectName'] as String;
    final contentType =
        session['contentType'] as String? ?? 'application/octet-stream';

    final chunks = <int>[];
    await for (final chunk in request.read()) {
      chunks.addAll(chunk);
      if (chunks.length > _maxUploadBytes) {
        return jsonErr(413, {
          'message':
              'File exceeds maximum size of ${_maxUploadBytes ~/ (1024 * 1024)} MB',
        });
      }
    }
    final bytes = chunks;

    try {
      final sink = _cloudStorage.bucket(_studioBucket).write(
        objectName,
        length: bytes.length,
        contentType: contentType,
      );
      sink.add(bytes);
      await sink.close();

      return jsonOk({
        'ok': true,
        'bucket': _studioBucket,
        'object': objectName,
      });
    } catch (e) {
      logger.e(message: 'Failed to store upload $uploadId', error: e);
      return jsonErr(500, {'message': 'Failed to store uploaded file'});
    }
  }

  // -----------------------------------------------------------------------
  // Generate (all task types)
  // -----------------------------------------------------------------------

  @Route.post('/generate')
  Future<Response> generate(Request request) async {
    
    late AudioGenerateRequest generateRequest;
    try {
      generateRequest = await parseJsonRequestBody(
        request,
        AudioGenerateRequest.fromJson,
      );
    } catch (e) {
      return jsonErr(400, {'message': 'Invalid request format'});
    }

    if (!_client.hasModel(generateRequest.model)) {
      return jsonErr(400, {
        'message': 'Unknown model: ${generateRequest.model}',
        'available_models': _client.models.toList(),
      });
    }

    final validationError = generateRequest.validate();
    if (validationError != null) {
      return jsonErr(400, {'message': validationError});
    }

    final payload = generateRequest.toJson();
    payload.remove('model');

    final taskId = const Uuid().v4();

    await _setTask(
      _TaskStatus(
        taskId: taskId,
        status: 'processing',
        taskType: generateRequest.taskType,
        model: generateRequest.model,
      ),
    );

    await _taskRepository.createTask(
      taskId: taskId,
      userId: request.userId,
      request: generateRequest,
      workspaceId: generateRequest.workspaceId,
    );

    unawaited(
      _runGeneration(
        taskId,
        () => _client.submit(
          generateRequest.model,
          payload,
          userId: request.userId,
        ),
      ),
    );

    return jsonOk({'task_id': taskId});
  }

  // -----------------------------------------------------------------------
  // Task polling
  // -----------------------------------------------------------------------

  @Route.get('/tasks/<taskId>')
  Future<Response> getTaskStatus(Request request, String taskId) async {
    final task = await _getTask(taskId);
    if (task == null) {
      return jsonErr(404, {'message': 'Task not found'});
    }

    final response = <String, dynamic>{
      'task_id': task.taskId,
      'status': task.status,
      'task_type': task.taskType,
      if (task.model != null) 'model': task.model,
    };

    if (task.status == 'complete' && task.result != null) {
      response['result'] = task.result;
    }
    if (task.status == 'failed' && task.error != null) {
      response['error'] = task.error;
    }

    return jsonOk(response);
  }

  // -----------------------------------------------------------------------
  // Internal
  // -----------------------------------------------------------------------

  Future<void> _runGeneration(
    String taskId,
    Future<Map<String, dynamic>> Function() clientCall,
  ) async {
    try {
      final result = await clientCall();

      final prev = await _getTask(taskId);
      await _setTask(
        _TaskStatus(
          taskId: taskId,
          status: 'complete',
          taskType: prev?.taskType ?? 'unknown',
          model: prev?.model,
          result: result,
        ),
      );

      try {
        await _taskRepository.markComplete(taskId: taskId, result: result);
      } catch (e, s) {
        logger.e(
          message: 'Failed to persist audio task completion',
          error: e,
          stackTrace: s,
        );
      }
    } catch (e) {
      logger.e(message: 'Audio generation failed for task $taskId', error: e);
      final prev = await _getTask(taskId);
      await _setTask(
        _TaskStatus(
          taskId: taskId,
          status: 'failed',
          taskType: prev?.taskType ?? 'unknown',
          model: prev?.model,
          error: 'Generation failed',
        ),
      );

      try {
        await _taskRepository.markFailed(
          taskId: taskId,
          error: 'Generation failed',
        );
      } catch (dbError, s) {
        logger.e(
          message: 'Failed to persist audio task failure',
          error: dbError,
          stackTrace: s,
        );
      }
    }
  }

  // -----------------------------------------------------------------------
  // LoRA
  // -----------------------------------------------------------------------

  static const _loraModel = 'ace_step_15';

  @Route.get('/lora/list')
  Future<Response> loraList(Request request) async {
   
    try {
      final result = await _client.getLoraList(_loraModel);
      return jsonOk(result);
    } on AudioModelException catch (e) {
      return jsonErr(e.statusCode, {'message': e.body});
    } catch (e) {
      logger.e(message: 'LoRA list failed', error: e);
      return jsonErr(500, {'message': 'Internal server error'});
    }
  }

  @Route.get('/lora/status')
  Future<Response> loraStatus(Request request) async {


    try {
      final result = await _client.getLoraStatus(_loraModel);
      return jsonOk(result);
    } on AudioModelException catch (e) {
      return jsonErr(e.statusCode, {'message': e.body});
    } catch (e) {
      logger.e(message: 'LoRA status failed', error: e);
      return jsonErr(500, {'message': 'Internal server error'});
    }
  }

  @Route.post('/lora/load')
  Future<Response> loadLora(Request request) async {


    final body =
        jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final loraPath = body['lora_path'] as String?;
    if (loraPath == null || loraPath.isEmpty) {
      return jsonErr(400, {'message': 'lora_path is required'});
    }

    final adapterName = body['adapter_name'] as String?;

    try {
      final result = await _client.loadLora(
        _loraModel,
        loraPath,
        adapterName: adapterName,
      );
      return jsonOk(result);
    } on AudioModelException catch (e) {
      return jsonErr(e.statusCode, {'message': e.body});
    } catch (e) {
      logger.e(message: 'LoRA load failed', error: e);
      return jsonErr(500, {'message': 'Internal server error'});
    }
  }

  @Route.post('/lora/unload')
  Future<Response> unloadLora(Request request) async {


    try {
      final result = await _client.unloadLora(_loraModel);
      return jsonOk(result);
    } on AudioModelException catch (e) {
      return jsonErr(e.statusCode, {'message': e.body});
    } catch (e) {
      logger.e(message: 'LoRA unload failed', error: e);
      return jsonErr(500, {'message': 'Internal server error'});
    }
  }

  @Route.post('/lora/toggle')
  Future<Response> toggleLora(Request request) async {


    final body =
        jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final useLora = body['use_lora'] as bool?;
    if (useLora == null) {
      return jsonErr(400, {'message': 'use_lora is required'});
    }

    try {
      final result = await _client.toggleLora(_loraModel, useLora);
      return jsonOk(result);
    } on AudioModelException catch (e) {
      return jsonErr(e.statusCode, {'message': e.body});
    } catch (e) {
      logger.e(message: 'LoRA toggle failed', error: e);
      return jsonErr(500, {'message': 'Internal server error'});
    }
  }

  @Route.post('/lora/scale')
  Future<Response> setLoraScale(Request request) async {


    final body =
        jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final scale = (body['scale'] as num?)?.toDouble();
    if (scale == null) {
      return jsonErr(400, {'message': 'scale is required'});
    }

    final adapterName = body['adapter_name'] as String?;

    try {
      final result = await _client.setLoraScale(
        _loraModel,
        scale,
        adapterName: adapterName,
      );
      return jsonOk(result);
    } on AudioModelException catch (e) {
      return jsonErr(e.statusCode, {'message': e.body});
    } catch (e) {
      logger.e(message: 'LoRA scale failed', error: e);
      return jsonErr(500, {'message': 'Internal server error'});
    }
  }

  // -----------------------------------------------------------------------
  // Internal
  // -----------------------------------------------------------------------

  Future<void> _setTask(_TaskStatus task) async {
    await _cache.set(
      key: '$_cachePrefix${task.taskId}',
      value: jsonEncode(task.toJson()),
      ttl: _taskTtl,
    );
  }

  Future<_TaskStatus?> _getTask(String taskId) async {
    final raw = await _cache.get(key: '$_cachePrefix$taskId');
    if (raw == null) return null;
    return _TaskStatus.fromJson(
      jsonDecode(raw as String) as Map<String, dynamic>,
    );
  }
}
