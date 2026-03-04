import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:studio_backend/src/audio/dto/audio_generate_request.dart';
import 'package:studio_backend/src/audio/task_status_values.dart';
import 'package:studio_backend/src/database/database.dart';
import 'package:studio_backend/src/database/postgres.dart';
import 'package:studio_backend/src/utils/cursor_pagination.dart';

class AudioGenerationTaskRepositoryImpl
    implements AudioGenerationTaskRepository {
  AudioGenerationTaskRepositoryImpl({required Database database})
    : _database = database;

  final Database _database;

  @override
  Future<String?> createTask({
    required String taskId,
    required String userId,
    required AudioGenerateRequest request,
    String? workspaceId,
  }) async {
    // Upsert: if a non-empty title matches an existing song by the same user,
    // replace that row instead of inserting a new one.
    final title = request.title;
    if (title != null && title.isNotEmpty) {
      final existing = await (_database.select(_database.audioGenerationTask)
            ..where(
                (t) => t.userId.equals(userId) & t.title.equals(title))
            ..limit(1))
          .getSingleOrNull();

      if (existing != null) {
        final oldTaskId = existing.taskId;
        await (_database.update(_database.audioGenerationTask)
              ..where((t) => t.id.equals(existing.id)))
            .write(AudioGenerationTaskCompanion(
          taskId: Value(taskId),
          model: Value(request.model),
          taskType: Value(request.taskType),
          status: const Value(TaskStatusValues.processing),
          prompt: Value(request.prompt),
          lyrics: Value(request.lyrics),
          negativePrompt: Value(request.negativePrompt),
          srcAudioPath: Value(request.srcAudioPath),
          infillStart: Value(request.infillStart),
          infillEnd: Value(request.infillEnd),
          stemName: Value(request.stemName),
          trackClasses: Value(
            request.trackClasses != null
                ? jsonEncode(request.trackClasses)
                : null,
          ),
          thinking: Value(request.thinking),
          constrainedDecoding: Value(request.constrainedDecoding),
          guidanceScale: Value(request.guidanceScale),
          inferMethod: Value(request.inferMethod),
          inferenceSteps: Value(request.inferenceSteps),
          cfgIntervalStart: Value(request.cfgIntervalStart),
          cfgIntervalEnd: Value(request.cfgIntervalEnd),
          shift: Value(request.shift),
          timeSignature: Value(request.timeSignature),
          temperature: Value(request.temperature),
          cfgScale: Value(request.cfgScale),
          topP: Value(request.topP),
          repetitionPenalty: Value(request.repetitionPenalty),
          audioDuration: Value(request.audioDuration),
          batchSize: Value(request.batchSize),
          useRandomSeed: Value(request.useRandomSeed),
          audioFormat: Value(request.audioFormat),
          workspaceId: Value(workspaceId),
          lyricSheetId: Value(request.lyricSheetId),
          result: const Value(null),
          error: const Value(null),
          completedAt: const Value(null),
          createdAt: Value(DateTime.now().toPgDateTime()),
        ));
        return oldTaskId;
      }
    }

    await _database.audioGenerationTask.insertOne(
      AudioGenerationTaskCompanion.insert(
        userId: userId,
        taskId: taskId,
        model: request.model,
        taskType: request.taskType,
        status: TaskStatusValues.processing,
        title: Value(request.title),
        prompt: Value(request.prompt),
        lyrics: Value(request.lyrics),
        negativePrompt: Value(request.negativePrompt),
        srcAudioPath: Value(request.srcAudioPath),
        infillStart: Value(request.infillStart),
        infillEnd: Value(request.infillEnd),
        stemName: Value(request.stemName),
        trackClasses: Value(
          request.trackClasses != null
              ? jsonEncode(request.trackClasses)
              : null,
        ),
        thinking: Value(request.thinking),
        constrainedDecoding: Value(request.constrainedDecoding),
        guidanceScale: Value(request.guidanceScale),
        inferMethod: Value(request.inferMethod),
        inferenceSteps: Value(request.inferenceSteps),
        cfgIntervalStart: Value(request.cfgIntervalStart),
        cfgIntervalEnd: Value(request.cfgIntervalEnd),
        shift: Value(request.shift),
        timeSignature: Value(request.timeSignature),
        temperature: Value(request.temperature),
        cfgScale: Value(request.cfgScale),
        topP: Value(request.topP),
        repetitionPenalty: Value(request.repetitionPenalty),
        audioDuration: Value(request.audioDuration),
        batchSize: Value(request.batchSize),
        useRandomSeed: Value(request.useRandomSeed),
        audioFormat: Value(request.audioFormat),
        workspaceId: Value(workspaceId),
        lyricSheetId: Value(request.lyricSheetId),
      ),
    );
    return null;
  }

  @override
  Future<void> markComplete({
    required String taskId,
    required Map<String, dynamic> result,
  }) async {
    await (_database.update(
      _database.audioGenerationTask,
    )..where((t) => t.taskId.equals(taskId))).write(
      AudioGenerationTaskCompanion(
        status: const Value(TaskStatusValues.complete),
        result: Value(jsonEncode(result)),
        completedAt: Value(DateTime.now().toPgDateTime()),
      ),
    );
  }

  @override
  Future<void> markFailed({
    required String taskId,
    required String error,
  }) async {
    await (_database.update(
      _database.audioGenerationTask,
    )..where((t) => t.taskId.equals(taskId))).write(
      AudioGenerationTaskCompanion(
        status: const Value(TaskStatusValues.failed),
        error: Value(error),
        completedAt: Value(DateTime.now().toPgDateTime()),
      ),
    );
  }

  @override
  Future<(List<AudioGenerationTaskEntity>, bool)> getSongsByUserId({
    required String userId,
    required int limit,
    PaginationCursor? cursor,
    int? rating,
    bool descending = true,
    String? workspaceId,
  }) async {
    final mode = descending ? OrderingMode.desc : OrderingMode.asc;
    final query = _database.select(_database.audioGenerationTask)
      ..where(
        (t) {
          var clause = t.userId.equals(userId) &
              t.status.equals(TaskStatusValues.complete) &
              buildCursorWhereClause(t.createdAt, t.id, cursor,
                  descending: descending);
          if (rating != null) {
            clause = clause & t.rating.equals(rating);
          }
          if (workspaceId != null) {
            clause = clause & t.workspaceId.equals(workspaceId);
          }
          return clause;
        },
      )
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: mode),
        (t) => OrderingTerm(expression: t.id, mode: mode),
      ])
      ..limit(limit + 1);

    final results = await query.get();
    final hasMore = results.length > limit;
    final trimmed = hasMore ? results.take(limit).toList() : results;

    return (trimmed, hasMore);
  }

  @override
  Future<void> createUploadTask({
    required String taskId,
    required String userId,
    required String objectPath,
    String? workspaceId,
  }) async {
    await _database.audioGenerationTask.insertOne(
      AudioGenerationTaskCompanion.insert(
        userId: userId,
        taskId: taskId,
        model: 'upload',
        taskType: 'upload',
        status: TaskStatusValues.uploading,
        srcAudioPath: Value(objectPath),
        workspaceId: Value(workspaceId),
      ),
    );
  }

  @override
  Future<AudioGenerationTaskEntity?> getSongByTaskId({
    required String userId,
    required String taskId,
  }) async {
    final query = _database.select(_database.audioGenerationTask)
      ..where((t) => t.userId.equals(userId) & t.taskId.equals(taskId));

    return query.getSingleOrNull();
  }

  @override
  Future<void> updateTitle({
    required String taskId,
    required String userId,
    required String title,
  }) async {
    await (_database.update(_database.audioGenerationTask)
          ..where((t) => t.taskId.equals(taskId) & t.userId.equals(userId)))
        .write(AudioGenerationTaskCompanion(title: Value(title)));
  }

  @override
  Future<void> updateRating({
    required String taskId,
    required String userId,
    required int? rating,
  }) async {
    await (_database.update(_database.audioGenerationTask)
          ..where((t) => t.taskId.equals(taskId) & t.userId.equals(userId)))
        .write(AudioGenerationTaskCompanion(rating: Value(rating)));
  }

  @override
  Future<void> updateWorkspace({
    required String taskId,
    required String userId,
    required String workspaceId,
  }) async {
    await (_database.update(_database.audioGenerationTask)
          ..where((t) => t.taskId.equals(taskId) & t.userId.equals(userId)))
        .write(AudioGenerationTaskCompanion(workspaceId: Value(workspaceId)));
  }

  @override
  Future<bool> deleteSong({
    required String taskId,
    required String userId,
  }) async {
    final deletedCount = await (_database.delete(
      _database.audioGenerationTask,
    )..where((t) => t.taskId.equals(taskId) & t.userId.equals(userId))).go();
    return deletedCount > 0;
  }

  @override
  Future<List<AudioGenerationTaskEntity>> getSongsByTaskIds({
    required List<String> taskIds,
    required String userId,
  }) async {
    final query = _database.select(_database.audioGenerationTask)
      ..where((t) => t.taskId.isIn(taskIds) & t.userId.equals(userId));
    return query.get();
  }

  @override
  Future<int> deleteSongs({
    required List<String> taskIds,
    required String userId,
  }) async {
    return await (_database.delete(_database.audioGenerationTask)
          ..where((t) => t.taskId.isIn(taskIds) & t.userId.equals(userId)))
        .go();
  }

  @override
  Future<List<AudioGenerationTaskEntity>> getSongsByLyricSheetId({
    required String lyricSheetId,
    required String userId,
  }) async {
    return (_database.select(_database.audioGenerationTask)
          ..where((t) =>
              t.lyricSheetId.equals(lyricSheetId) &
              t.userId.equals(userId) &
              t.status.equals(TaskStatusValues.complete))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  @override
  Future<void> updateLyricSheetId({
    required String taskId,
    required String userId,
    required String? lyricSheetId,
  }) async {
    await (_database.update(_database.audioGenerationTask)
          ..where((t) => t.taskId.equals(taskId) & t.userId.equals(userId)))
        .write(
            AudioGenerationTaskCompanion(lyricSheetId: Value(lyricSheetId)));
  }

  @override
  Future<void> clearLyricSheetId({required String lyricSheetId}) async {
    await (_database.update(_database.audioGenerationTask)
          ..where((t) => t.lyricSheetId.equals(lyricSheetId)))
        .write(
            const AudioGenerationTaskCompanion(lyricSheetId: Value(null)));
  }

  @override
  Future<(List<AudioGenerationTaskEntity>, bool)> searchSongsByLyrics({
    required String userId,
    required String query,
    required int limit,
    PaginationCursor? cursor,
    bool descending = true,
    String? workspaceId,
  }) async {
    final mode = descending ? OrderingMode.desc : OrderingMode.asc;
    final pattern = '%$query%';
    final q = _database.select(_database.audioGenerationTask)
      ..where((t) {
        var clause = t.userId.equals(userId) &
            t.status.equals(TaskStatusValues.complete) &
            t.lyrics.lower().like(pattern.toLowerCase()) &
            buildCursorWhereClause(t.createdAt, t.id, cursor,
                descending: descending);
        if (workspaceId != null) {
          clause = clause & t.workspaceId.equals(workspaceId);
        }
        return clause;
      })
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: mode),
        (t) => OrderingTerm(expression: t.id, mode: mode),
      ])
      ..limit(limit + 1);

    final results = await q.get();
    final hasMore = results.length > limit;
    final trimmed = hasMore ? results.take(limit).toList() : results;
    return (trimmed, hasMore);
  }
}

abstract class AudioGenerationTaskRepository {
  /// Creates a new task row, or upserts when [AudioGenerateRequest.title] is
  /// non-empty and already exists for [userId].
  ///
  /// Returns the previous `taskId` that was replaced, or `null` for a fresh
  /// insert.
  Future<String?> createTask({
    required String taskId,
    required String userId,
    required AudioGenerateRequest request,
    String? workspaceId,
  });

  Future<void> markComplete({
    required String taskId,
    required Map<String, dynamic> result,
  });

  Future<void> markFailed({required String taskId, required String error});

  Future<(List<AudioGenerationTaskEntity>, bool)> getSongsByUserId({
    required String userId,
    required int limit,
    PaginationCursor? cursor,
    int? rating,
    bool descending = true,
    String? workspaceId,
  });

  Future<AudioGenerationTaskEntity?> getSongByTaskId({
    required String userId,
    required String taskId,
  });

  Future<void> createUploadTask({
    required String taskId,
    required String userId,
    required String objectPath,
    String? workspaceId,
  });

  Future<void> updateTitle({
    required String taskId,
    required String userId,
    required String title,
  });

  Future<void> updateRating({
    required String taskId,
    required String userId,
    required int? rating,
  });

  Future<void> updateWorkspace({
    required String taskId,
    required String userId,
    required String workspaceId,
  });

  Future<bool> deleteSong({required String taskId, required String userId});

  Future<List<AudioGenerationTaskEntity>> getSongsByTaskIds({
    required List<String> taskIds,
    required String userId,
  });

  Future<int> deleteSongs({
    required List<String> taskIds,
    required String userId,
  });

  Future<List<AudioGenerationTaskEntity>> getSongsByLyricSheetId({
    required String lyricSheetId,
    required String userId,
  });

  Future<void> updateLyricSheetId({
    required String taskId,
    required String userId,
    required String? lyricSheetId,
  });

  Future<void> clearLyricSheetId({required String lyricSheetId});

  Future<(List<AudioGenerationTaskEntity>, bool)> searchSongsByLyrics({
    required String userId,
    required String query,
    required int limit,
    PaginationCursor? cursor,
    bool descending = true,
    String? workspaceId,
  });
}
