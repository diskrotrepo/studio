import 'dart:convert';

import 'package:drift_postgres/drift_postgres.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:studio_backend/src/audio/audio_generation_task_repository.dart';
import 'package:studio_backend/src/database/database.dart';
import 'package:studio_backend/src/lyric_book/lyric_book_repository.dart';
import 'package:studio_backend/src/lyric_book/lyric_book_service.dart';
import 'package:test/test.dart';

class MockLyricBookRepository extends Mock implements LyricBookRepository {}

class MockAudioGenerationTaskRepository extends Mock
    implements AudioGenerationTaskRepository {}

Request _request(
  String method,
  String path, {
  Map<String, dynamic>? body,
  String userId = 'user-1',
}) {
  return Request(
    method,
    Uri.parse('http://localhost$path'),
    headers: {'Diskrot-User-Id': userId},
    body: body != null ? jsonEncode(body) : null,
  );
}

LyricSheetEntity _sheet({
  String id = 'sheet-1',
  String userId = 'user-1',
  String title = 'My Song',
  String content = 'Verse 1...',
}) =>
    LyricSheetEntity(
      id: id,
      createdAt: PgDateTime(DateTime(2025, 1, 1)),
      userId: userId,
      title: title,
      content: content,
    );

void main() {
  late MockLyricBookRepository repository;
  late MockAudioGenerationTaskRepository taskRepository;
  late Router router;

  setUp(() {
    repository = MockLyricBookRepository();
    taskRepository = MockAudioGenerationTaskRepository();
    final service = LyricBookService(
      repository: repository,
      taskRepository: taskRepository,
    );
    router = service.router;
  });

  group('POST /', () {
    test('creates lyric sheet', () async {
      when(() => repository.create(
            userId: any(named: 'userId'),
            title: any(named: 'title'),
            content: any(named: 'content'),
          )).thenAnswer((_) async => _sheet());

      final response = await router.call(
        _request('POST', '/', body: {'title': 'My Song', 'content': 'Verse 1...'}),
      );

      expect(response.statusCode, 200);
      final json = jsonDecode(await response.readAsString());
      expect(json['id'], 'sheet-1');
      expect(json['title'], 'My Song');
    });

    test('returns 400 when title exceeds 500 chars', () async {
      final response = await router.call(
        _request('POST', '/', body: {
          'title': 'a' * 501,
          'content': 'ok',
        }),
      );

      expect(response.statusCode, 400);
      final json = jsonDecode(await response.readAsString());
      expect(json['message'], contains('title'));
    });

    test('returns 400 when content exceeds 100000 chars', () async {
      final response = await router.call(
        _request('POST', '/', body: {
          'title': 'ok',
          'content': 'a' * 100001,
        }),
      );

      expect(response.statusCode, 400);
      final json = jsonDecode(await response.readAsString());
      expect(json['message'], contains('content'));
    });
  });

  group('GET /<id>', () {
    test('returns 404 when sheet belongs to different user', () async {
      when(() => repository.getById('sheet-1'))
          .thenAnswer((_) async => _sheet(userId: 'other-user'));

      final response = await router.call(
        _request('GET', '/sheet-1'),
      );

      expect(response.statusCode, 404);
    });
  });

  group('PATCH /<id>', () {
    test('updates sheet', () async {
      when(() => repository.getById('sheet-1'))
          .thenAnswer((_) async => _sheet());
      when(() => repository.update(
            id: any(named: 'id'),
            title: any(named: 'title'),
            content: any(named: 'content'),
          )).thenAnswer((_) async {});

      final response = await router.call(
        _request('PATCH', '/sheet-1', body: {'title': 'New Title'}),
      );

      expect(response.statusCode, 200);
      verify(() => repository.update(
            id: 'sheet-1',
            title: 'New Title',
            content: null,
          )).called(1);
    });

    test('returns 400 when title exceeds 500 chars on update', () async {
      when(() => repository.getById('sheet-1'))
          .thenAnswer((_) async => _sheet());

      final response = await router.call(
        _request('PATCH', '/sheet-1', body: {'title': 'a' * 501}),
      );

      expect(response.statusCode, 400);
    });
  });

  group('DELETE /<id>', () {
    test('unlinks songs then deletes sheet', () async {
      when(() => repository.getById('sheet-1'))
          .thenAnswer((_) async => _sheet());
      when(() => taskRepository.clearLyricSheetId(
            lyricSheetId: any(named: 'lyricSheetId'),
          )).thenAnswer((_) async {});
      when(() => repository.delete(any())).thenAnswer((_) async {});

      final response = await router.call(
        _request('DELETE', '/sheet-1'),
      );

      expect(response.statusCode, 200);
      verify(() => taskRepository.clearLyricSheetId(lyricSheetId: 'sheet-1'))
          .called(1);
      verify(() => repository.delete('sheet-1')).called(1);
    });
  });

  group('GET /search', () {
    test('returns 400 when q parameter is missing', () async {
      final response = await router.call(
        _request('GET', '/search'),
      );

      expect(response.statusCode, 400);
      final json = jsonDecode(await response.readAsString());
      expect(json['message'], contains('q parameter'));
    });

    test('returns matching sheets', () async {
      when(() => repository.search(
            userId: any(named: 'userId'),
            query: any(named: 'query'),
          )).thenAnswer((_) async => [_sheet()]);

      final response = await router.call(
        _request('GET', '/search?q=verse'),
      );

      expect(response.statusCode, 200);
      final json = jsonDecode(await response.readAsString());
      expect((json['data'] as List).length, 1);
    });
  });
}
