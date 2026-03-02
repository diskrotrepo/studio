import 'dart:convert';

import 'package:mocktail/mocktail.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:studio_backend/src/settings/settings_repository.dart';
import 'package:studio_backend/src/user/user_repository.dart';
import 'package:studio_backend/src/user/user_service.dart';
import 'package:test/test.dart';

class MockUserRepository extends Mock implements UserRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

Router _buildRouter(UserService service) {
  final r = Router();
  r.get('/me', service.me);
  r.get('/<userId>', service.getUser);
  return r;
}

void main() {
  late MockUserRepository userRepository;
  late MockSettingsRepository settingsRepository;
  late UserService service;
  late Router router;

  setUp(() {
    userRepository = MockUserRepository();
    settingsRepository = MockSettingsRepository();
    service = UserService(
      userRepository: userRepository,
      settingsRepository: settingsRepository,
    );
    router = _buildRouter(service);
  });

  group('GET /me', () {
    test('returns external user ID', () async {
      when(() => settingsRepository.getExternalUserId())
          .thenAnswer((_) async => 'ext-user-123');

      final response = await router.call(
        Request(
          'GET',
          Uri.parse('http://localhost/me'),
          headers: {'Diskrot-User-Id': 'user-1'},
        ),
      );

      expect(response.statusCode, 200);
      final json = jsonDecode(await response.readAsString());
      expect(json['user_id'], 'ext-user-123');
    });
  });

  group('GET /<userId>', () {
    test('returns user when request is admin (local, no signature headers)',
        () async {
      when(() => userRepository.getUser(userId: 'target-user'))
          .thenAnswer((_) async => null);

      final response = await router.call(
        Request(
          'GET',
          Uri.parse('http://localhost/target-user'),
          headers: {'Diskrot-User-Id': 'user-1'},
        ),
      );

      expect(response.statusCode, 200);
    });

    test('returns 403 when request is not admin (has X-Signature header)',
        () async {
      final response = await router.call(
        Request(
          'GET',
          Uri.parse('http://localhost/target-user'),
          headers: {
            'Diskrot-User-Id': 'user-1',
            'X-Signature': 'some-signature',
          },
        ),
      );

      expect(response.statusCode, 403);
    });
  });
}
