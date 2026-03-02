import 'package:flutter_test/flutter_test.dart';
import 'package:studio_ui/models/task_status.dart';

void main() {
  group('TaskStatus.fromJson', () {
    test('parses all fields', () {
      final task = TaskStatus.fromJson({
        'task_id': 'abc-123',
        'status': 'processing',
        'task_type': 'generate',
        'error': 'some error',
        'title': 'My Song',
        'rating': 5,
        'result': {'url': 'http://example.com/audio.mp3'},
      });

      expect(task.taskId, 'abc-123');
      expect(task.status, 'processing');
      expect(task.taskType, 'generate');
      expect(task.error, 'some error');
      expect(task.title, 'My Song');
      expect(task.rating, 5);
      expect(task.result, isNotNull);
    });

    test('defaults task_type to unknown when missing', () {
      final task = TaskStatus.fromJson({
        'task_id': 'id',
        'status': 'complete',
      });

      expect(task.taskType, 'unknown');
    });

    test('handles null optional fields', () {
      final task = TaskStatus.fromJson({
        'task_id': 'id',
        'status': 'complete',
        'task_type': 'generate',
      });

      expect(task.error, isNull);
      expect(task.result, isNull);
      expect(task.title, isNull);
      expect(task.rating, isNull);
    });
  });

  group('TaskStatus.fromSongJson', () {
    test('parses song-specific fields', () {
      final task = TaskStatus.fromSongJson({
        'task_id': 'song-1',
        'status': 'complete',
        'task_type': 'generate',
        'prompt': 'a chill lofi beat',
        'model': 'ace_step_15',
        'title': 'Chill Vibes',
        'lyrics': 'La la la',
        'rating': 4,
        'created_at': '2025-01-15T10:30:00.000Z',
        'result': {'url': 'http://example.com'},
      });

      expect(task.taskId, 'song-1');
      expect(task.prompt, 'a chill lofi beat');
      expect(task.model, 'ace_step_15');
      expect(task.title, 'Chill Vibes');
      expect(task.lyrics, 'La la la');
      expect(task.rating, 4);
      expect(task.createdAt, isNotNull);
      expect(task.createdAt!.year, 2025);
    });

    test('defaults status to complete when missing', () {
      final task = TaskStatus.fromSongJson({
        'task_id': 'id',
      });

      expect(task.status, 'complete');
    });

    test('defaults task_type to unknown when missing', () {
      final task = TaskStatus.fromSongJson({
        'task_id': 'id',
      });

      expect(task.taskType, 'unknown');
    });

    test('handles null created_at', () {
      final task = TaskStatus.fromSongJson({
        'task_id': 'id',
      });

      expect(task.createdAt, isNull);
    });

    test('handles invalid created_at', () {
      final task = TaskStatus.fromSongJson({
        'task_id': 'id',
        'created_at': 'not-a-date',
      });

      expect(task.createdAt, isNull);
    });
  });

  group('boolean getters', () {
    test('isProcessing', () {
      final task = TaskStatus(
        taskId: 'id',
        status: 'processing',
        taskType: 'generate',
      );
      expect(task.isProcessing, true);
      expect(task.isComplete, false);
      expect(task.isFailed, false);
      expect(task.isUploading, false);
    });

    test('isUploading', () {
      final task = TaskStatus(
        taskId: 'id',
        status: 'uploading',
        taskType: 'generate',
      );
      expect(task.isUploading, true);
      expect(task.isActive, true);
    });

    test('isComplete', () {
      final task = TaskStatus(
        taskId: 'id',
        status: 'complete',
        taskType: 'generate',
      );
      expect(task.isComplete, true);
      expect(task.isActive, false);
    });

    test('isFailed', () {
      final task = TaskStatus(
        taskId: 'id',
        status: 'failed',
        taskType: 'generate',
      );
      expect(task.isFailed, true);
      expect(task.isActive, false);
    });

    test('isActive is true for processing and uploading', () {
      expect(
        TaskStatus(taskId: 'id', status: 'processing', taskType: 't').isActive,
        true,
      );
      expect(
        TaskStatus(taskId: 'id', status: 'uploading', taskType: 't').isActive,
        true,
      );
      expect(
        TaskStatus(taskId: 'id', status: 'complete', taskType: 't').isActive,
        false,
      );
      expect(
        TaskStatus(taskId: 'id', status: 'failed', taskType: 't').isActive,
        false,
      );
    });
  });

  group('copyWith', () {
    final original = TaskStatus(
      taskId: 'id',
      status: 'complete',
      taskType: 'generate',
      prompt: 'prompt',
      model: 'model',
      title: 'Original Title',
      lyrics: 'Original Lyrics',
      rating: 3,
      createdAt: DateTime(2025, 1, 1),
    );

    test('preserves all fields when no overrides', () {
      final copy = original.copyWith();

      expect(copy.taskId, original.taskId);
      expect(copy.status, original.status);
      expect(copy.title, original.title);
      expect(copy.lyrics, original.lyrics);
      expect(copy.rating, original.rating);
      expect(copy.prompt, original.prompt);
      expect(copy.model, original.model);
      expect(copy.createdAt, original.createdAt);
    });

    test('overrides title', () {
      final copy = original.copyWith(title: 'New Title');
      expect(copy.title, 'New Title');
      expect(copy.lyrics, 'Original Lyrics');
    });

    test('overrides lyrics', () {
      final copy = original.copyWith(lyrics: 'New Lyrics');
      expect(copy.lyrics, 'New Lyrics');
    });

    test('overrides rating', () {
      final copy = original.copyWith(rating: 5);
      expect(copy.rating, 5);
    });

    test('clearLyrics sets lyrics to null', () {
      final copy = original.copyWith(clearLyrics: true);
      expect(copy.lyrics, isNull);
    });

    test('clearRating sets rating to null', () {
      final copy = original.copyWith(clearRating: true);
      expect(copy.rating, isNull);
    });

    test('clearLyrics takes precedence over lyrics param', () {
      final copy = original.copyWith(
        lyrics: 'Ignored',
        clearLyrics: true,
      );
      expect(copy.lyrics, isNull);
    });
  });
}
