import 'package:mocktail/mocktail.dart';
import 'package:shelf/shelf.dart';
import 'package:studio_backend/src/middleware/user_middleware.dart';
import 'package:studio_backend/src/user/user_repository.dart';
import 'package:test/test.dart';

class MockUserRepository extends Mock implements UserRepository {}

void main() {
  late MockUserRepository repo;

  setUp(() {
    repo = MockUserRepository();
    when(() => repo.ensureUser(externalUserId: any(named: 'externalUserId')))
        .thenAnswer((_) async {});
  });

  Handler _buildHandler() {
    return const Pipeline()
        .addMiddleware(userAutoCreateMiddleware(repo))
        .addHandler((request) => Response.ok('ok'));
  }

  group('userAutoCreateMiddleware', () {
    test('creates user when valid Diskrot-User-Id header is present', () async {
      final handler = _buildHandler();

      final request = Request(
        'GET',
        Uri.parse('http://localhost/test'),
        headers: {'Diskrot-User-Id': 'user-abc-123'},
      );

      final response = await handler(request);

      expect(response.statusCode, 200);
      verify(() => repo.ensureUser(externalUserId: 'user-abc-123')).called(1);
    });

    test('does not create user when header is missing', () async {
      final handler = _buildHandler();

      final request = Request(
        'GET',
        Uri.parse('http://localhost/test'),
      );

      final response = await handler(request);

      expect(response.statusCode, 200);
      verifyNever(
          () => repo.ensureUser(externalUserId: any(named: 'externalUserId')));
    });

    test('does not re-create known users', () async {
      final handler = _buildHandler();

      final request1 = Request(
        'GET',
        Uri.parse('http://localhost/test'),
        headers: {'Diskrot-User-Id': 'repeat-user'},
      );
      final request2 = Request(
        'GET',
        Uri.parse('http://localhost/test'),
        headers: {'Diskrot-User-Id': 'repeat-user'},
      );

      await handler(request1);
      await handler(request2);

      verify(() => repo.ensureUser(externalUserId: 'repeat-user')).called(1);
    });

    test('rejects invalid user ID with spaces', () async {
      final handler = _buildHandler();

      final request = Request(
        'GET',
        Uri.parse('http://localhost/test'),
        headers: {'Diskrot-User-Id': 'bad user id'},
      );

      final response = await handler(request);

      expect(response.statusCode, 200);
      verifyNever(
          () => repo.ensureUser(externalUserId: any(named: 'externalUserId')));
    });

    test('rejects invalid user ID with special characters', () async {
      final handler = _buildHandler();

      final request = Request(
        'GET',
        Uri.parse('http://localhost/test'),
        headers: {'Diskrot-User-Id': '../etc/passwd'},
      );

      final response = await handler(request);

      expect(response.statusCode, 200);
      verifyNever(
          () => repo.ensureUser(externalUserId: any(named: 'externalUserId')));
    });

    test('skips creation for peer requests with X-Signature header', () async {
      final handler = _buildHandler();

      final request = Request(
        'GET',
        Uri.parse('http://localhost/test'),
        headers: {
          'Diskrot-User-Id': 'user-abc-123',
          'X-Signature': 'some-signature',
        },
      );

      final response = await handler(request);

      expect(response.statusCode, 200);
      verifyNever(
          () => repo.ensureUser(externalUserId: any(named: 'externalUserId')));
    });

    test('passes request through to inner handler in all cases', () async {
      var handlerCalled = false;
      final handler = const Pipeline()
          .addMiddleware(userAutoCreateMiddleware(repo))
          .addHandler((request) {
        handlerCalled = true;
        return Response.ok('inner');
      });

      // With valid user ID
      await handler(Request(
        'GET',
        Uri.parse('http://localhost/test'),
        headers: {'Diskrot-User-Id': 'valid-user-1'},
      ));
      expect(handlerCalled, isTrue);

      // Without user ID
      handlerCalled = false;
      await handler(Request(
        'GET',
        Uri.parse('http://localhost/test'),
      ));
      expect(handlerCalled, isTrue);

      // With X-Signature
      handlerCalled = false;
      await handler(Request(
        'GET',
        Uri.parse('http://localhost/test'),
        headers: {'X-Signature': 'sig'},
      ));
      expect(handlerCalled, isTrue);

      // With invalid user ID
      handlerCalled = false;
      await handler(Request(
        'GET',
        Uri.parse('http://localhost/test'),
        headers: {'Diskrot-User-Id': 'invalid user!!'},
      ));
      expect(handlerCalled, isTrue);
    });
  });
}
