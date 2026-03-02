import 'dart:convert';

import 'package:drift_postgres/drift_postgres.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shelf/shelf.dart';
import 'package:studio_backend/src/database/database.dart';
import 'package:studio_backend/src/middleware/forwarding_middleware.dart';
import 'package:studio_backend/src/server_backends/server_backend_repository.dart';
import 'package:studio_backend/src/settings/settings_repository.dart';
import 'package:test/test.dart';

class MockServerBackendRepository extends Mock
    implements ServerBackendRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late MockServerBackendRepository backendRepo;
  late MockSettingsRepository settingsRepo;

  setUp(() {
    backendRepo = MockServerBackendRepository();
    settingsRepo = MockSettingsRepository();
  });

  Handler _buildHandler({Handler? inner}) {
    final innerHandler = inner ?? (Request request) => Response.ok('local');
    return const Pipeline()
        .addMiddleware(forwardingMiddleware(
          serverBackendRepository: backendRepo,
          settingsRepository: settingsRepo,
        ))
        .addHandler(innerHandler);
  }

  ServerBackendEntity _fakeBackend() {
    return ServerBackendEntity(
      id: 'backend-1',
      createdAt: PgDateTime(DateTime(2025, 1, 1)),
      name: 'Remote Server',
      apiHost: 'remote.example.com:8080',
      secure: true,
      isActive: true,
    );
  }

  group('forwardingMiddleware', () {
    group('passes through local-only paths', () {
      final localOnlyPrefixes = [
        'v1/health',
        'v1/peers',
        'v1/server-backends',
        'v1/settings',
        'v1/users/me',
        'v1/browse',
      ];

      for (final prefix in localOnlyPrefixes) {
        test('passes through $prefix even when remote backend is active',
            () async {
          // Setup an active backend - but it should be ignored for local paths.
          when(() => backendRepo.getActive())
              .thenAnswer((_) async => _fakeBackend());

          var innerHandlerCalled = false;
          final handler = _buildHandler(
            inner: (request) {
              innerHandlerCalled = true;
              return Response.ok('local');
            },
          );

          final request = Request(
            'GET',
            Uri.parse('http://localhost/$prefix/some-sub-path'),
          );

          final response = await handler(request);

          expect(response.statusCode, 200);
          expect(await response.readAsString(), 'local');
          expect(innerHandlerCalled, isTrue);
          // getActive() should never be called for local-only paths.
          verifyNever(() => backendRepo.getActive());
        });
      }
    });

    test('passes through when no active backend exists', () async {
      when(() => backendRepo.getActive()).thenAnswer((_) async => null);

      var innerHandlerCalled = false;
      final handler = _buildHandler(
        inner: (request) {
          innerHandlerCalled = true;
          return Response.ok('local');
        },
      );

      final request = Request(
        'GET',
        Uri.parse('http://localhost/v1/songs'),
      );

      final response = await handler(request);

      expect(response.statusCode, 200);
      expect(await response.readAsString(), 'local');
      expect(innerHandlerCalled, isTrue);
      verify(() => backendRepo.getActive()).called(1);
    });

    test('returns 500 when server private key is not found', () async {
      when(() => backendRepo.getActive())
          .thenAnswer((_) async => _fakeBackend());
      when(() => settingsRepo.getServerPrivateKey())
          .thenAnswer((_) async => null);
      when(() => settingsRepo.getServerPublicKey())
          .thenAnswer((_) async => 'some-public-key');

      final handler = _buildHandler();

      final request = Request(
        'GET',
        Uri.parse('http://localhost/v1/songs'),
      );

      final response = await handler(request);

      expect(response.statusCode, 500);
      final body = jsonDecode(await response.readAsString());
      expect(body['message'], contains('keys not configured'));
    });

    test('returns 500 when server public key is not found', () async {
      when(() => backendRepo.getActive())
          .thenAnswer((_) async => _fakeBackend());
      when(() => settingsRepo.getServerPrivateKey())
          .thenAnswer((_) async => 'some-private-key');
      when(() => settingsRepo.getServerPublicKey())
          .thenAnswer((_) async => null);

      final handler = _buildHandler();

      final request = Request(
        'POST',
        Uri.parse('http://localhost/v1/songs'),
        body: jsonEncode({'title': 'Test Song'}),
        headers: {'content-type': 'application/json'},
      );

      final response = await handler(request);

      expect(response.statusCode, 500);
      final body = jsonDecode(await response.readAsString());
      expect(body['message'], contains('keys not configured'));
    });

    test('does not call inner handler when forwarding to remote', () async {
      when(() => backendRepo.getActive())
          .thenAnswer((_) async => _fakeBackend());
      when(() => settingsRepo.getServerPrivateKey())
          .thenAnswer((_) async => null);
      when(() => settingsRepo.getServerPublicKey())
          .thenAnswer((_) async => null);

      var innerHandlerCalled = false;
      final handler = _buildHandler(
        inner: (request) {
          innerHandlerCalled = true;
          return Response.ok('local');
        },
      );

      final request = Request(
        'GET',
        Uri.parse('http://localhost/v1/songs'),
      );

      await handler(request);

      // The inner handler should NOT be called when there is an active backend,
      // regardless of whether the forwarding succeeds or fails.
      expect(innerHandlerCalled, isFalse);
    });
  });
}
