import 'dart:convert';

import 'package:drift_postgres/drift_postgres.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:studio_backend/src/database/database.dart';
import 'package:studio_backend/src/peers/peer_repository.dart';
import 'package:studio_backend/src/peers/peer_service.dart';
import 'package:test/test.dart';

class MockPeerRepository extends Mock implements PeerRepository {}

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
  late MockPeerRepository repository;
  late PeerService service;
  late Router router;

  setUp(() {
    repository = MockPeerRepository();
    service = PeerService(repository: repository);
    router = service.router;
  });

  group('GET /', () {
    test('returns list of peers', () async {
      when(() => repository.getAll()).thenAnswer(
        (_) async => [
          PeerConnectionEntity(
            id: 'peer-1',
            publicKey: 'pk-abc',
            firstSeenAt: PgDateTime(DateTime(2025, 1, 1)),
            lastSeenAt: PgDateTime(DateTime(2025, 6, 15)),
            requestCount: 42,
            blocked: false,
          ),
          PeerConnectionEntity(
            id: 'peer-2',
            publicKey: 'pk-def',
            firstSeenAt: PgDateTime(DateTime(2025, 3, 10)),
            lastSeenAt: PgDateTime(DateTime(2025, 6, 20)),
            requestCount: 7,
            blocked: true,
          ),
        ],
      );

      final response = await router.call(_request('GET', '/'));

      expect(response.statusCode, 200);
      final json = jsonDecode(await response.readAsString());
      expect(json['data'], hasLength(2));
      expect(json['data'][0]['id'], 'peer-1');
      expect(json['data'][0]['public_key'], 'pk-abc');
      expect(json['data'][0]['request_count'], 42);
      expect(json['data'][0]['blocked'], false);
      expect(json['data'][1]['id'], 'peer-2');
      expect(json['data'][1]['blocked'], true);
    });
  });

  group('PUT /<id>/block', () {
    test('blocks a peer', () async {
      when(() => repository.setBlocked(any(), blocked: true))
          .thenAnswer((_) async {});

      final response = await router.call(
        _request('PUT', '/peer-1/block'),
      );

      expect(response.statusCode, 200);
      final json = jsonDecode(await response.readAsString());
      expect(json['success'], true);
      verify(() => repository.setBlocked('peer-1', blocked: true)).called(1);
    });
  });

  group('PUT /<id>/unblock', () {
    test('unblocks a peer', () async {
      when(() => repository.setBlocked(any(), blocked: false))
          .thenAnswer((_) async {});

      final response = await router.call(
        _request('PUT', '/peer-1/unblock'),
      );

      expect(response.statusCode, 200);
      final json = jsonDecode(await response.readAsString());
      expect(json['success'], true);
      verify(() => repository.setBlocked('peer-1', blocked: false)).called(1);
    });
  });
}
