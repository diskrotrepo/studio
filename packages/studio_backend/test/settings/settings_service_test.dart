import 'dart:convert';

import 'package:mocktail/mocktail.dart';
import 'package:shelf/shelf.dart';
import 'package:studio_backend/src/settings/settings_repository.dart';
import 'package:studio_backend/src/settings/settings_service.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

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
  late MockSettingsRepository repository;
  late SettingsService service;
  late Router router;

  setUp(() {
    repository = MockSettingsRepository();
    service = SettingsService(settingsRepository: repository);
    router = service.router;
  });

  group('GET /', () {
    test('returns all settings', () async {
      when(() => repository.getAll()).thenAnswer(
        (_) async => {
          'lyrics_system_prompt': 'You are a lyricist.',
          'prompt_system_prompt': 'You are a producer.',
        },
      );

      final response = await router.call(_request('GET', '/'));

      expect(response.statusCode, 200);
      final json = jsonDecode(await response.readAsString())
          as Map<String, dynamic>;
      expect(json['lyrics_system_prompt'], 'You are a lyricist.');
      expect(json['prompt_system_prompt'], 'You are a producer.');
    });
  });

  group('PUT /', () {
    test('updates allowed settings', () async {
      when(() => repository.updateAll(any())).thenAnswer((_) async {});

      final response = await router.call(
        _request('PUT', '/', body: {
          'lyrics_system_prompt': 'New lyrics prompt',
          'prompt_system_prompt': 'New prompt prompt',
        }),
      );

      expect(response.statusCode, 200);
      final json = jsonDecode(await response.readAsString());
      expect(json['success'], true);

      final captured = verify(() => repository.updateAll(captureAny()))
          .captured
          .single as Map<String, String>;
      expect(captured['lyrics_system_prompt'], 'New lyrics prompt');
      expect(captured['prompt_system_prompt'], 'New prompt prompt');
    });

    test('filters out disallowed keys', () async {
      when(() => repository.updateAll(any())).thenAnswer((_) async {});

      final response = await router.call(
        _request('PUT', '/', body: {
          'lyrics_system_prompt': 'Valid',
          'evil_key': 'should be ignored',
        }),
      );

      expect(response.statusCode, 200);

      final captured = verify(() => repository.updateAll(captureAny()))
          .captured
          .single as Map<String, String>;
      expect(captured, {'lyrics_system_prompt': 'Valid'});
      expect(captured.containsKey('evil_key'), false);
    });

    test('returns 400 when no valid settings provided', () async {
      final response = await router.call(
        _request('PUT', '/', body: {
          'unknown_key': 'value',
          'another_bad': 'value',
        }),
      );

      expect(response.statusCode, 400);
      final json = jsonDecode(await response.readAsString());
      expect(json['message'], contains('No valid settings'));
      verifyNever(() => repository.updateAll(any()));
    });

    test('returns 400 when body is empty map', () async {
      final response = await router.call(
        _request('PUT', '/', body: {}),
      );

      expect(response.statusCode, 400);
    });
  });
}
