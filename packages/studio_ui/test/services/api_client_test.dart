import 'package:flutter_test/flutter_test.dart';
import 'package:studio_ui/services/api_client.dart';

import '../helpers/fake_http_client.dart';
import '../helpers/test_api_client.dart';

void main() {
  late ApiClient apiClient;
  late FakeHttpClient fakeClient;

  setUp(() {
    final t = createTestApiClient();
    apiClient = t.apiClient;
    fakeClient = t.fakeClient;
  });

  group('ApiClient.submitTask', () {
    test('returns task ID on 200', () async {
      fakeClient.respondJson({'task_id': 'abc-123'});
      final id = await apiClient.submitTask({'model': 'test'});
      expect(id, 'abc-123');
    });

    test('throws ApiException on non-200', () async {
      fakeClient.respondError(500, message: 'Internal error');
      expect(
        () => apiClient.submitTask({'model': 'test'}),
        throwsA(isA<ApiException>()),
      );
    });

    test('includes server message in ApiException', () async {
      fakeClient.respondError(400, message: 'Bad model name');
      try {
        await apiClient.submitTask({'model': 'bad'});
        fail('Expected ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 400);
        expect(e.message, 'Bad model name');
      }
    });
  });

  group('ApiClient.getTaskStatus', () {
    test('returns TaskStatus on 200', () async {
      fakeClient.respondJson({
        'task_id': 'id-1',
        'status': 'complete',
        'task_type': 'generate',
      });
      final status = await apiClient.getTaskStatus('id-1');
      expect(status.taskId, 'id-1');
      expect(status.isComplete, true);
    });

    test('throws ApiException with 404 for missing task', () async {
      fakeClient.respondError(404);
      try {
        await apiClient.getTaskStatus('missing');
        fail('Expected ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 404);
      }
    });

    test('throws ApiException on server error', () async {
      fakeClient.respondError(500);
      expect(
        () => apiClient.getTaskStatus('id-1'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('ApiClient.getSongs', () {
    test('returns songs list on 200', () async {
      fakeClient.respondJson({
        'data': [
          {'task_id': 's1', 'status': 'complete', 'task_type': 'generate'},
        ],
        'nextCursor': 'cur1',
        'hasMore': true,
      });
      final result = await apiClient.getSongs();
      expect(result.songs, hasLength(1));
      expect(result.songs.first.taskId, 's1');
      expect(result.nextCursor, 'cur1');
      expect(result.hasMore, true);
    });

    test('handles empty data array', () async {
      fakeClient.respondJson({'data': [], 'hasMore': false});
      final result = await apiClient.getSongs();
      expect(result.songs, isEmpty);
      expect(result.hasMore, false);
    });

    test('handles missing data key', () async {
      fakeClient.respondJson({'hasMore': false});
      final result = await apiClient.getSongs();
      expect(result.songs, isEmpty);
    });
  });

  group('ApiClient.getUserId', () {
    test('returns user ID on 200', () async {
      fakeClient.respondJson({'user_id': 'user-42'});
      final id = await apiClient.getUserId();
      expect(id, 'user-42');
    });

    test('throws on non-200', () async {
      fakeClient.respondError(500);
      expect(() => apiClient.getUserId(), throwsA(isA<ApiException>()));
    });
  });

  group('ApiClient.healthCheck', () {
    test('returns map on 200', () async {
      fakeClient.respondJson({'status': 'ok', 'model': 'test'});
      final result = await apiClient.healthCheck();
      expect(result['status'], 'ok');
    });

    test('throws on non-200', () async {
      fakeClient.respondError(503);
      expect(() => apiClient.healthCheck(), throwsA(isA<ApiException>()));
    });
  });

  group('ApiException', () {
    test('toString returns message', () {
      final e = ApiException(404, 'Not found');
      expect(e.toString(), 'Not found');
    });

    test('statusCode is preserved', () {
      final e = ApiException(503, 'Unavailable');
      expect(e.statusCode, 503);
    });
  });
}
