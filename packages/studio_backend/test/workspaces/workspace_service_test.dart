import 'dart:convert';

import 'package:drift_postgres/drift_postgres.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:studio_backend/src/database/database.dart';
import 'package:studio_backend/src/workspaces/workspace_repository.dart';
import 'package:studio_backend/src/workspaces/workspace_service.dart';
import 'package:test/test.dart';

class MockWorkspaceRepository extends Mock implements WorkspaceRepository {}

WorkspaceEntity _workspace({
  required String id,
  required String userId,
  required String name,
  bool isDefault = false,
}) {
  return WorkspaceEntity(
    id: id,
    createdAt: PgDateTime(DateTime(2025, 1, 1)),
    userId: userId,
    name: name,
    isDefault: isDefault,
  );
}

Request _request(
  String method,
  String path, {
  Map<String, dynamic>? body,
}) {
  return Request(
    method,
    Uri.parse('http://localhost$path'),
    headers: {'Diskrot-User-Id': 'user-1'},
    body: body != null ? jsonEncode(body) : null,
  );
}

void main() {
  late MockWorkspaceRepository repository;
  late WorkspaceService service;
  late Router router;

  setUp(() {
    repository = MockWorkspaceRepository();
    service = WorkspaceService(repository: repository);
    router = service.router;
  });

  group('POST /', () {
    test('creates workspace with valid name', () async {
      when(() => repository.create(
            userId: any(named: 'userId'),
            name: any(named: 'name'),
          )).thenAnswer(
        (_) async => _workspace(
          id: 'ws-1',
          userId: 'user-1',
          name: 'My Project',
        ),
      );

      final response = await router.call(
        _request('POST', '/', body: {'name': 'My Project'}),
      );

      expect(response.statusCode, 200);
      final json = jsonDecode(await response.readAsString());
      expect(json['id'], 'ws-1');
      expect(json['name'], 'My Project');
      expect(json['is_default'], false);
    });

    test('returns 400 when name is empty', () async {
      final response = await router.call(
        _request('POST', '/', body: {'name': ''}),
      );

      expect(response.statusCode, 400);
      final json = jsonDecode(await response.readAsString());
      expect(json['message'], contains('name'));
    });

    test('returns 400 when name exceeds 200 chars', () async {
      final response = await router.call(
        _request('POST', '/', body: {'name': 'a' * 201}),
      );

      expect(response.statusCode, 400);
      final json = jsonDecode(await response.readAsString());
      expect(json['message'], contains('exceeds maximum length'));
    });
  });

  group('PUT /<id>', () {
    test('renames workspace', () async {
      when(() => repository.getById('ws-1')).thenAnswer(
        (_) async => _workspace(
          id: 'ws-1',
          userId: 'user-1',
          name: 'Old Name',
        ),
      );
      when(() => repository.rename(
            id: any(named: 'id'),
            name: any(named: 'name'),
          )).thenAnswer((_) async {});

      final response = await router.call(
        _request('PUT', '/ws-1', body: {'name': 'New Name'}),
      );

      expect(response.statusCode, 200);
      final json = jsonDecode(await response.readAsString());
      expect(json['success'], true);

      verify(() => repository.rename(id: 'ws-1', name: 'New Name')).called(1);
    });

    test('returns 404 when workspace belongs to different user', () async {
      when(() => repository.getById('ws-other')).thenAnswer(
        (_) async => _workspace(
          id: 'ws-other',
          userId: 'user-2',
          name: 'Other Workspace',
        ),
      );

      final response = await router.call(
        _request('PUT', '/ws-other', body: {'name': 'Hijack'}),
      );

      expect(response.statusCode, 404);
      final json = jsonDecode(await response.readAsString());
      expect(json['message'], contains('not found'));
    });
  });

  group('DELETE /<id>', () {
    test('returns 400 when trying to delete default workspace', () async {
      when(() => repository.getById('ws-default')).thenAnswer(
        (_) async => _workspace(
          id: 'ws-default',
          userId: 'user-1',
          name: 'Default',
          isDefault: true,
        ),
      );

      final response = await router.call(
        _request('DELETE', '/ws-default'),
      );

      expect(response.statusCode, 400);
      final json = jsonDecode(await response.readAsString());
      expect(json['message'], contains('default'));
      verifyNever(() => repository.delete(any()));
    });
  });
}
