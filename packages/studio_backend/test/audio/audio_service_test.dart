import 'dart:convert';

import 'package:drift_postgres/drift_postgres.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:studio_backend/src/audio/audio_client.dart';
import 'package:studio_backend/src/audio/audio_generation_task_repository.dart';
import 'package:studio_backend/src/audio/audio_model_client.dart';
import 'package:studio_backend/src/audio/audio_service.dart';
import 'package:studio_backend/src/audio/dto/audio_generate_request.dart';
import 'package:studio_backend/src/database/database.dart';
import 'package:studio_backend/src/storage/cloud_storage.dart';
import 'package:test/test.dart';

import '../fake/fake_cache.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockAudioClient extends Mock implements AudioClient {}

class MockAudioGenerationTaskRepository extends Mock
    implements AudioGenerationTaskRepository {}

class MockCloudStorage extends Mock implements CloudStorage {}

class MockBucket extends Mock implements Bucket {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Request _request(
  String method,
  String path, {
  Map<String, dynamic>? body,
  Map<String, String>? headers,
}) {
  return Request(
    method,
    Uri.parse('http://localhost$path'),
    headers: {
      'Diskrot-User-Id': 'user-1',
      if (body != null) 'Content-Type': 'application/json',
      ...?headers,
    },
    body: body != null ? jsonEncode(body) : null,
  );
}

Router _buildRouter(AudioService service) {
  final r = Router();
  r.get('/health', service.health);
  r.get('/<model>/defaults', service.modelDefaults);
  r.get('/<model>/capabilities', service.modelCapabilities);
  r.get('/songs', service.getSongs);
  r.get('/songs/<songId>', service.getSong);
  r.post('/upload', service.createUpload);
  r.put('/upload/finalize', service.finalizeUpload);
  r.post('/generate', service.generate);
  r.get('/tasks/<taskId>', service.getTaskStatus);
  r.get('/lora/list', service.loraList);
  return r;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockAudioClient client;
  late FakeCache cache;
  late MockAudioGenerationTaskRepository taskRepository;
  late MockCloudStorage cloudStorage;
  late MockBucket bucket;
  late AudioService service;
  late Router router;

  setUpAll(() {
    registerFallbackValue(
      AudioGenerateRequest(model: 'x', taskType: 'generate'),
    );
  });

  setUp(() {
    client = MockAudioClient();
    cache = FakeCache();
    taskRepository = MockAudioGenerationTaskRepository();
    cloudStorage = MockCloudStorage();
    bucket = MockBucket();

    when(() => cloudStorage.bucket(any())).thenReturn(bucket);

    service = AudioService(
      audioClient: client,
      cache: cache,
      studioBucket: 'test-bucket',
      audioGenerationTaskRepository: taskRepository,
      cloudStorage: cloudStorage,
    );
    router = _buildRouter(service);
  });

  // -------------------------------------------------------------------------
  // Health
  // -------------------------------------------------------------------------

  group('GET /health', () {
    test('returns status ok when all models healthy', () async {
      when(() => client.models).thenReturn(['model_a']);
      when(() => client.healthCheck('model_a')).thenAnswer((_) async => true);

      final response = await router.call(_request('GET', '/health'));

      expect(response.statusCode, 200);
      final json = jsonDecode(await response.readAsString());
      expect(json['status'], 'ok');
      expect(json['models']['model_a'], true);
    });

    test('returns status degraded when a model is unhealthy', () async {
      when(() => client.models).thenReturn(['model_a', 'model_b']);
      when(() => client.healthCheck('model_a')).thenAnswer((_) async => true);
      when(() => client.healthCheck('model_b')).thenAnswer((_) async => false);

      final response = await router.call(_request('GET', '/health'));

      expect(response.statusCode, 200);
      final json = jsonDecode(await response.readAsString());
      expect(json['status'], 'degraded');
      expect(json['models']['model_a'], true);
      expect(json['models']['model_b'], false);
    });

    test('returns ok with empty models map when no models configured',
        () async {
      when(() => client.models).thenReturn([]);

      final response = await router.call(_request('GET', '/health'));

      expect(response.statusCode, 200);
      final json = jsonDecode(await response.readAsString());
      expect(json['status'], 'ok');
      expect(json['models'], isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // Model defaults
  // -------------------------------------------------------------------------

  group('GET /<model>/defaults', () {
    test('returns defaults for known model', () async {
      when(() => client.getDefaults('model_a'))
          .thenReturn({'key': 'value', 'tempo': 120});

      final response =
          await router.call(_request('GET', '/model_a/defaults'));

      expect(response.statusCode, 200);
      final json = jsonDecode(await response.readAsString());
      expect(json['data']['key'], 'value');
      expect(json['data']['tempo'], 120);
    });

    test('returns 404 for unknown model', () async {
      when(() => client.getDefaults('unknown')).thenReturn(null);
      when(() => client.models).thenReturn(['model_a']);

      final response =
          await router.call(_request('GET', '/unknown/defaults'));

      expect(response.statusCode, 404);
      final json = jsonDecode(await response.readAsString());
      expect(json['message'], contains('Unknown model'));
      expect(json['available_models'], contains('model_a'));
    });
  });

  // -------------------------------------------------------------------------
  // Capabilities
  // -------------------------------------------------------------------------

  group('GET /<model>/capabilities', () {
    test('returns capabilities for known model', () async {
      when(() => client.getCapabilities('model_a'))
          .thenReturn({'task_types': ['generate'], 'model': 'model_a'});

      final response =
          await router.call(_request('GET', '/model_a/capabilities'));

      expect(response.statusCode, 200);
      final json = jsonDecode(await response.readAsString());
      expect(json['data']['task_types'], contains('generate'));
    });

    test('returns 404 for unknown model', () async {
      when(() => client.getCapabilities('unknown')).thenReturn(null);
      when(() => client.models).thenReturn(['model_a']);

      final response =
          await router.call(_request('GET', '/unknown/capabilities'));

      expect(response.statusCode, 404);
      final json = jsonDecode(await response.readAsString());
      expect(json['message'], contains('Unknown model'));
    });
  });

  // -------------------------------------------------------------------------
  // Upload
  // -------------------------------------------------------------------------

  group('POST /upload', () {
    test('creates upload session', () async {
      final response = await router.call(_request('POST', '/upload', body: {
        'filename': 'test.wav',
        'contentType': 'audio/wav',
        'size': 1024,
      }));

      expect(response.statusCode, 200);
      final json = jsonDecode(await response.readAsString());
      expect(json['objectName'], isNotEmpty);
      expect(json['uploadUrl'], isNotEmpty);
      expect(json['id'], isNotEmpty);
      expect(json['size'], 1024);
      expect(json['contentType'], 'audio/wav');
    });

    test('returns 413 when file exceeds max size', () async {
      final response = await router.call(_request('POST', '/upload', body: {
        'filename': 'huge.wav',
        'contentType': 'audio/wav',
        'size': 500 * 1024 * 1024 + 1, // 500 MB + 1 byte
      }));

      expect(response.statusCode, 413);
      final json = jsonDecode(await response.readAsString());
      expect(json['message'], contains('maximum size'));
    });

    test('returns 400 when filename is missing', () async {
      final response = await router.call(_request('POST', '/upload', body: {
        'contentType': 'audio/wav',
        'size': 1024,
      }));

      expect(response.statusCode, 400);
      final json = jsonDecode(await response.readAsString());
      expect(json['message'], contains('filename'));
    });

    test('returns 400 when contentType is missing', () async {
      final response = await router.call(_request('POST', '/upload', body: {
        'filename': 'test.wav',
        'size': 1024,
      }));

      expect(response.statusCode, 400);
      final json = jsonDecode(await response.readAsString());
      expect(json['message'], contains('contentType'));
    });

    test('returns 400 when size is missing', () async {
      final response = await router.call(_request('POST', '/upload', body: {
        'filename': 'test.wav',
        'contentType': 'audio/wav',
      }));

      expect(response.statusCode, 400);
      final json = jsonDecode(await response.readAsString());
      expect(json['message'], contains('size'));
    });
  });

  // -------------------------------------------------------------------------
  // Upload finalize
  // -------------------------------------------------------------------------

  group('PUT /upload/finalize', () {
    test('returns 400 when Diskrot-File-Id header is missing', () async {
      final response = await router.call(
        _request('PUT', '/upload/finalize'),
      );

      expect(response.statusCode, 400);
      final json = jsonDecode(await response.readAsString());
      expect(json['message'], contains('Diskrot-File-Id'));
    });

    test('returns 400 when upload session is not found', () async {
      final response = await router.call(
        _request(
          'PUT',
          '/upload/finalize',
          headers: {'Diskrot-File-Id': 'nonexistent-id'},
        ),
      );

      expect(response.statusCode, 400);
      final json = jsonDecode(await response.readAsString());
      expect(json['message'], contains('not found'));
    });
  });

  // -------------------------------------------------------------------------
  // Songs
  // -------------------------------------------------------------------------

  group('GET /songs', () {
    test('returns songs for user', () async {
      when(() => taskRepository.getSongsByUserId(
            userId: any(named: 'userId'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
            rating: any(named: 'rating'),
            descending: any(named: 'descending'),
            workspaceId: any(named: 'workspaceId'),
          )).thenAnswer(
              (_) async => (<AudioGenerationTaskEntity>[], false));

      final response = await router.call(
        _request('GET', '/songs'),
      );

      expect(response.statusCode, 200);
      final json = jsonDecode(await response.readAsString());
      expect(json['data'], isEmpty);
      expect(json['hasMore'], false);
      expect(json['nextCursor'], isNull);
    });

    test('returns songs with data', () async {
      final entity = AudioGenerationTaskEntity(
        id: '1',
        createdAt: PgDateTime(DateTime(2025, 1, 1)),
        userId: 'user-1',
        model: 'model_a',
        taskType: 'generate',
        taskId: 'task-1',
        status: 'complete',
        prompt: 'A cool song',
        title: 'My Song',
      );

      when(() => taskRepository.getSongsByUserId(
            userId: any(named: 'userId'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
            rating: any(named: 'rating'),
            descending: any(named: 'descending'),
            workspaceId: any(named: 'workspaceId'),
          )).thenAnswer((_) async => ([entity], false));

      final response = await router.call(
        _request('GET', '/songs'),
      );

      expect(response.statusCode, 200);
      final json = jsonDecode(await response.readAsString());
      expect(json['data'], hasLength(1));
      expect(json['data'][0]['task_id'], 'task-1');
      expect(json['data'][0]['title'], 'My Song');
      expect(json['data'][0]['prompt'], 'A cool song');
      expect(json['hasMore'], false);
    });
  });

  // -------------------------------------------------------------------------
  // Get single song
  // -------------------------------------------------------------------------

  group('GET /songs/<songId>', () {
    test('returns 404 when song does not exist', () async {
      when(() => taskRepository.getSongByTaskId(
            userId: any(named: 'userId'),
            taskId: any(named: 'taskId'),
          )).thenAnswer((_) async => null);

      final response = await router.call(
        _request('GET', '/songs/nonexistent'),
      );

      expect(response.statusCode, 404);
      final json = jsonDecode(await response.readAsString());
      expect(json['message'], 'Song not found');
    });

    test('returns song details when found', () async {
      final entity = AudioGenerationTaskEntity(
        id: '1',
        createdAt: PgDateTime(DateTime(2025, 1, 1)),
        userId: 'user-1',
        model: 'model_a',
        taskType: 'generate',
        taskId: 'task-42',
        status: 'complete',
        prompt: 'Epic rock ballad',
        title: 'Ballad',
      );

      when(() => taskRepository.getSongByTaskId(
            userId: any(named: 'userId'),
            taskId: any(named: 'taskId'),
          )).thenAnswer((_) async => entity);

      final response = await router.call(
        _request('GET', '/songs/task-42'),
      );

      expect(response.statusCode, 200);
      final json = jsonDecode(await response.readAsString());
      expect(json['task_id'], 'task-42');
      expect(json['title'], 'Ballad');
      expect(json['parameters'], isA<Map>());
    });
  });

  // -------------------------------------------------------------------------
  // Task status
  // -------------------------------------------------------------------------

  group('GET /tasks/<taskId>', () {
    test('returns 404 for unknown task', () async {
      final response = await router.call(
        _request('GET', '/tasks/nonexistent'),
      );

      expect(response.statusCode, 404);
      final json = jsonDecode(await response.readAsString());
      expect(json['message'], 'Task not found');
    });

    test('returns task status from cache', () async {
      // Seed the cache with a task
      await cache.set(
        key: 'audio_task:my-task-id',
        value: jsonEncode({
          'task_id': 'my-task-id',
          'status': 'processing',
          'task_type': 'generate',
          'model': 'model_a',
        }),
      );

      final response = await router.call(
        _request('GET', '/tasks/my-task-id'),
      );

      expect(response.statusCode, 200);
      final json = jsonDecode(await response.readAsString());
      expect(json['task_id'], 'my-task-id');
      expect(json['status'], 'processing');
      expect(json['task_type'], 'generate');
      expect(json['model'], 'model_a');
    });

    test('includes result when task is complete', () async {
      await cache.set(
        key: 'audio_task:done-task',
        value: jsonEncode({
          'task_id': 'done-task',
          'status': 'complete',
          'task_type': 'generate',
          'result': {'file': '/audio/output.mp3'},
        }),
      );

      final response = await router.call(
        _request('GET', '/tasks/done-task'),
      );

      expect(response.statusCode, 200);
      final json = jsonDecode(await response.readAsString());
      expect(json['status'], 'complete');
      expect(json['result']['file'], '/audio/output.mp3');
    });

    test('includes error when task has failed', () async {
      await cache.set(
        key: 'audio_task:fail-task',
        value: jsonEncode({
          'task_id': 'fail-task',
          'status': 'failed',
          'task_type': 'generate',
          'error': 'Generation failed',
        }),
      );

      final response = await router.call(
        _request('GET', '/tasks/fail-task'),
      );

      expect(response.statusCode, 200);
      final json = jsonDecode(await response.readAsString());
      expect(json['status'], 'failed');
      expect(json['error'], 'Generation failed');
    });
  });

  // -------------------------------------------------------------------------
  // LoRA
  // -------------------------------------------------------------------------

  group('GET /lora/list', () {
    test('returns lora list', () async {
      when(() => client.getLoraList('ace_step_15'))
          .thenAnswer((_) async => {'loras': []});

      final response = await router.call(_request('GET', '/lora/list'));

      expect(response.statusCode, 200);
      final json = jsonDecode(await response.readAsString());
      expect(json['loras'], isEmpty);
    });

    test('returns error status from AudioModelException', () async {
      when(() => client.getLoraList('ace_step_15'))
          .thenThrow(AudioModelException(502, 'upstream timeout'));

      final response = await router.call(_request('GET', '/lora/list'));

      expect(response.statusCode, 502);
      final json = jsonDecode(await response.readAsString());
      expect(json['message'], 'upstream timeout');
    });

    test('returns 500 with generic message on unexpected error', () async {
      when(() => client.getLoraList('ace_step_15'))
          .thenThrow(Exception('connection refused'));

      final response = await router.call(_request('GET', '/lora/list'));

      expect(response.statusCode, 500);
      final json = jsonDecode(await response.readAsString());
      // Must NOT leak internal exception details
      expect(json['message'], 'Internal server error');
      expect(json['message'], isNot(contains('connection refused')));
    });
  });

  // -------------------------------------------------------------------------
  // Generate
  // -------------------------------------------------------------------------

  group('POST /generate', () {
    test('returns 400 for unknown model', () async {
      when(() => client.hasModel(any())).thenReturn(false);
      when(() => client.models).thenReturn(['model_a']);

      final response =
          await router.call(_request('POST', '/generate', body: {
        'model': 'unknown',
        'task_type': 'generate',
        'prompt': 'test',
      }));

      expect(response.statusCode, 400);
      final json = jsonDecode(await response.readAsString());
      expect(json['message'], contains('Unknown model'));
      expect(json['available_models'], contains('model_a'));
    });

    test('returns 400 for invalid request format', () async {
      // Send a request with body that will fail AudioGenerateRequest.fromJson
      // (missing required fields model and task_type)
      final response = await router.call(
        Request(
          'POST',
          Uri.parse('http://localhost/generate'),
          headers: {
            'Diskrot-User-Id': 'user-1',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'not_a_valid_field': true}),
        ),
      );

      expect(response.statusCode, 400);
      final json = jsonDecode(await response.readAsString());
      expect(json['message'], contains('Invalid request'));
    });

    test('returns 400 for validation error (missing prompt)', () async {
      when(() => client.hasModel('model_a')).thenReturn(true);

      final response =
          await router.call(_request('POST', '/generate', body: {
        'model': 'model_a',
        'task_type': 'generate',
        // prompt is missing -- required for 'generate' task type
      }));

      expect(response.statusCode, 400);
      final json = jsonDecode(await response.readAsString());
      expect(json['message'], contains('prompt'));
    });

    test('accepts valid generate request', () async {
      when(() => client.hasModel('model_a')).thenReturn(true);
      when(() => taskRepository.createTask(
            taskId: any(named: 'taskId'),
            userId: any(named: 'userId'),
            request: any(named: 'request'),
            workspaceId: any(named: 'workspaceId'),
          )).thenAnswer((_) async => null);
      when(() => client.submit(
            any(),
            any(),
            userId: any(named: 'userId'),
          )).thenAnswer((_) async => {'file': '/output.mp3'});

      final response =
          await router.call(_request('POST', '/generate', body: {
        'model': 'model_a',
        'task_type': 'generate',
        'prompt': 'A relaxing piano piece',
      }));

      expect(response.statusCode, 200);
      final json = jsonDecode(await response.readAsString());
      expect(json['task_id'], isNotEmpty);
    });
  });
}
