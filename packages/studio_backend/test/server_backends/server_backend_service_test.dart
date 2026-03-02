import 'dart:convert';

import 'package:drift_postgres/drift_postgres.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shelf/shelf.dart';
import 'package:studio_backend/src/database/database.dart';
import 'package:studio_backend/src/server_backends/server_backend_repository.dart';
import 'package:studio_backend/src/server_backends/server_backend_service.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';

class MockServerBackendRepository extends Mock
    implements ServerBackendRepository {}

ServerBackendEntity _entity({
  required String id,
  required String name,
  required String apiHost,
  bool secure = false,
  bool isActive = false,
}) {
  return ServerBackendEntity(
    id: id,
    name: name,
    apiHost: apiHost,
    secure: secure,
    isActive: isActive,
    createdAt: PgDateTime(DateTime(2025, 1, 1)),
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
    body: body != null ? jsonEncode(body) : null,
  );
}

void main() {
  late MockServerBackendRepository repository;
  late ServerBackendService service;
  late Router router;

  setUp(() {
    repository = MockServerBackendRepository();
    service = ServerBackendService(repository: repository);
    router = service.router;
  });

  group('GET /', () {
    test('returns list of backends', () async {
      when(() => repository.getAll()).thenAnswer(
        (_) async => [
          _entity(id: '1', name: 'Local', apiHost: 'localhost:8080'),
          _entity(
            id: '2',
            name: 'Prod',
            apiHost: 'api.example.com',
            isActive: true,
          ),
        ],
      );

      final response = await router.call(_request('GET', '/'));

      expect(response.statusCode, 200);
      final json = jsonDecode(await response.readAsString());
      expect(json['data'], hasLength(2));
      expect(json['data'][0]['name'], 'Local');
      expect(json['data'][1]['is_active'], true);
    });

    test('returns empty list when no backends exist', () async {
      when(() => repository.getAll()).thenAnswer((_) async => []);

      final response = await router.call(_request('GET', '/'));

      expect(response.statusCode, 200);
      final json = jsonDecode(await response.readAsString());
      expect(json['data'], isEmpty);
    });
  });

  group('POST /', () {
    test('creates a backend', () async {
      when(
        () => repository.create(
          name: any(named: 'name'),
          apiHost: any(named: 'apiHost'),
          secure: any(named: 'secure'),
        ),
      ).thenAnswer(
        (_) async => _entity(
          id: 'new-id',
          name: 'New Backend',
          apiHost: 'api.new.com',
        ),
      );

      final response = await router.call(
        _request('POST', '/', body: {
          'name': 'New Backend',
          'api_host': 'api.new.com',
        }),
      );

      expect(response.statusCode, 200);
      final json = jsonDecode(await response.readAsString());
      expect(json['id'], 'new-id');
      expect(json['name'], 'New Backend');
      expect(json['api_host'], 'api.new.com');
      expect(json['secure'], false);
    });

    test('creates a backend with secure flag', () async {
      when(
        () => repository.create(
          name: any(named: 'name'),
          apiHost: any(named: 'apiHost'),
          secure: any(named: 'secure'),
        ),
      ).thenAnswer(
        (_) async => _entity(
          id: 'sec-id',
          name: 'Secure',
          apiHost: 'api.secure.com',
          secure: true,
        ),
      );

      final response = await router.call(
        _request('POST', '/', body: {
          'name': 'Secure',
          'api_host': 'api.secure.com',
          'secure': true,
        }),
      );

      expect(response.statusCode, 200);
      final json = jsonDecode(await response.readAsString());
      expect(json['secure'], true);
    });

    test('returns 400 when name is missing', () async {
      final response = await router.call(
        _request('POST', '/', body: {'api_host': 'api.example.com'}),
      );

      expect(response.statusCode, 400);
      final json = jsonDecode(await response.readAsString());
      expect(json['message'], contains('name'));
    });

    test('returns 400 when name is empty', () async {
      final response = await router.call(
        _request('POST', '/', body: {'name': '', 'api_host': 'host'}),
      );

      expect(response.statusCode, 400);
      final json = jsonDecode(await response.readAsString());
      expect(json['message'], contains('name'));
    });

    test('returns 400 when api_host is missing', () async {
      final response = await router.call(
        _request('POST', '/', body: {'name': 'My Backend'}),
      );

      expect(response.statusCode, 400);
      final json = jsonDecode(await response.readAsString());
      expect(json['message'], contains('api_host'));
    });

    test('returns 400 when api_host is empty', () async {
      final response = await router.call(
        _request('POST', '/', body: {'name': 'My Backend', 'api_host': ''}),
      );

      expect(response.statusCode, 400);
      final json = jsonDecode(await response.readAsString());
      expect(json['message'], contains('api_host'));
    });
  });

  group('PUT /<id>', () {
    test('updates a backend', () async {
      when(
        () => repository.update(
          id: any(named: 'id'),
          name: any(named: 'name'),
          apiHost: any(named: 'apiHost'),
          secure: any(named: 'secure'),
        ),
      ).thenAnswer((_) async {});

      final response = await router.call(
        _request('PUT', '/abc-123', body: {'name': 'Updated'}),
      );

      expect(response.statusCode, 200);
      final json = jsonDecode(await response.readAsString());
      expect(json['success'], true);

      verify(
        () => repository.update(
          id: 'abc-123',
          name: 'Updated',
          apiHost: null,
          secure: null,
        ),
      ).called(1);
    });
  });

  group('DELETE /<id>', () {
    test('deletes a non-active backend', () async {
      when(() => repository.getActive()).thenAnswer(
        (_) async => _entity(
          id: 'other-id',
          name: 'Active',
          apiHost: 'host',
          isActive: true,
        ),
      );
      when(() => repository.delete(any())).thenAnswer((_) async {});

      final response = await router.call(
        _request('DELETE', '/delete-me'),
      );

      expect(response.statusCode, 200);
      verify(() => repository.delete('delete-me')).called(1);
    });

    test('deletes when no active backend exists', () async {
      when(() => repository.getActive()).thenAnswer((_) async => null);
      when(() => repository.delete(any())).thenAnswer((_) async {});

      final response = await router.call(
        _request('DELETE', '/any-id'),
      );

      expect(response.statusCode, 200);
    });

    test('deactivates before deleting the active backend', () async {
      when(() => repository.getActive()).thenAnswer(
        (_) async => _entity(
          id: 'active-id',
          name: 'Active',
          apiHost: 'host',
          isActive: true,
        ),
      );
      when(() => repository.deactivate(any())).thenAnswer((_) async {});
      when(() => repository.delete(any())).thenAnswer((_) async {});

      final response = await router.call(
        _request('DELETE', '/active-id'),
      );

      expect(response.statusCode, 200);
      verify(() => repository.deactivate('active-id')).called(1);
      verify(() => repository.delete('active-id')).called(1);
    });
  });

  group('PUT /<id>/activate', () {
    test('activates a backend', () async {
      when(() => repository.setActive(any())).thenAnswer((_) async {});

      final response = await router.call(
        _request('PUT', '/backend-1/activate'),
      );

      expect(response.statusCode, 200);
      verify(() => repository.setActive('backend-1')).called(1);
    });
  });
}
