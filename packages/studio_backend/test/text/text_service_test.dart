import 'dart:convert';

import 'package:mocktail/mocktail.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:studio_backend/src/settings/settings_repository.dart';
import 'package:studio_backend/src/text/text_client.dart';
import 'package:studio_backend/src/text/text_service.dart';
import 'package:test/test.dart';

class MockTextClient extends Mock implements TextClient {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

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
  late MockTextClient textClient;
  late MockSettingsRepository settingsRepository;
  late TextService service;
  late Router router;

  setUp(() {
    textClient = MockTextClient();
    settingsRepository = MockSettingsRepository();
    service = TextService(
      textClient: textClient,
      settingsRepository: settingsRepository,
    );
    router = service.router;
  });

  group('POST /lyrics', () {
    test('returns lyrics for valid request', () async {
      when(() => textClient.hasModel('gpt-4')).thenReturn(true);
      when(() => textClient.models).thenReturn(['gpt-4']);
      when(() => settingsRepository.getLyricsSystemPrompt(
            audioModel: any(named: 'audioModel'),
          )).thenAnswer((_) async => 'system prompt');
      when(() => textClient.generateLyrics(
            any(),
            any(),
            systemPrompt: any(named: 'systemPrompt'),
          )).thenAnswer((_) async => 'These are the lyrics');

      final response = await router.call(
        _request('POST', '/lyrics', body: {
          'model': 'gpt-4',
          'description': 'A song about rain',
        }),
      );

      expect(response.statusCode, 200);
      final json = jsonDecode(await response.readAsString());
      expect(json['lyrics'], 'These are the lyrics');
    });

    test('returns 400 when model is missing', () async {
      final response = await router.call(
        _request('POST', '/lyrics', body: {
          'description': 'A song about rain',
        }),
      );

      expect(response.statusCode, 400);
      final json = jsonDecode(await response.readAsString());
      expect(json['message'], contains('model'));
    });

    test('returns 400 when description is missing', () async {
      final response = await router.call(
        _request('POST', '/lyrics', body: {
          'model': 'gpt-4',
        }),
      );

      expect(response.statusCode, 400);
      final json = jsonDecode(await response.readAsString());
      expect(json['message'], contains('description'));
    });

    test('returns 400 for unknown model', () async {
      when(() => textClient.hasModel('unknown')).thenReturn(false);
      when(() => textClient.models).thenReturn(['gpt-4']);

      final response = await router.call(
        _request('POST', '/lyrics', body: {
          'model': 'unknown',
          'description': 'A song about rain',
        }),
      );

      expect(response.statusCode, 400);
      final json = jsonDecode(await response.readAsString());
      expect(json['message'], contains('Unknown model'));
    });

    test('returns 400 when description exceeds max length', () async {
      final response = await router.call(
        _request('POST', '/lyrics', body: {
          'model': 'gpt-4',
          'description': 'a' * 10001,
        }),
      );

      expect(response.statusCode, 400);
      final json = jsonDecode(await response.readAsString());
      expect(json['message'], contains('exceeds maximum length'));
    });

    test('returns 500 with generic message on error', () async {
      when(() => textClient.hasModel('gpt-4')).thenReturn(true);
      when(() => textClient.models).thenReturn(['gpt-4']);
      when(() => settingsRepository.getLyricsSystemPrompt(
            audioModel: any(named: 'audioModel'),
          )).thenAnswer((_) async => 'system prompt');
      when(() => textClient.generateLyrics(
            any(),
            any(),
            systemPrompt: any(named: 'systemPrompt'),
          )).thenThrow(Exception('API key expired'));

      final response = await router.call(
        _request('POST', '/lyrics', body: {
          'model': 'gpt-4',
          'description': 'A song about rain',
        }),
      );

      expect(response.statusCode, 500);
      final json = jsonDecode(await response.readAsString());
      expect(json['message'], 'Internal server error');
    });
  });

  group('POST /prompt', () {
    test('returns prompt for valid request', () async {
      when(() => textClient.hasModel('gpt-4')).thenReturn(true);
      when(() => textClient.models).thenReturn(['gpt-4']);
      when(() => settingsRepository.getPromptSystemPrompt(
            audioModel: any(named: 'audioModel'),
          )).thenAnswer((_) async => 'system prompt');
      when(() => textClient.generatePrompt(
            any(),
            any(),
            systemPrompt: any(named: 'systemPrompt'),
          )).thenAnswer((_) async => 'Lo-fi hip hop, mellow vibes');

      final response = await router.call(
        _request('POST', '/prompt', body: {
          'model': 'gpt-4',
          'description': 'A chill beat',
        }),
      );

      expect(response.statusCode, 200);
      final json = jsonDecode(await response.readAsString());
      expect(json['prompt'], 'Lo-fi hip hop, mellow vibes');
    });

    test('returns 400 when model is missing', () async {
      final response = await router.call(
        _request('POST', '/prompt', body: {
          'description': 'A chill beat',
        }),
      );

      expect(response.statusCode, 400);
      final json = jsonDecode(await response.readAsString());
      expect(json['message'], contains('model'));
    });

    test('returns 500 with generic message on error', () async {
      when(() => textClient.hasModel('gpt-4')).thenReturn(true);
      when(() => textClient.models).thenReturn(['gpt-4']);
      when(() => settingsRepository.getPromptSystemPrompt(
            audioModel: any(named: 'audioModel'),
          )).thenAnswer((_) async => 'system prompt');
      when(() => textClient.generatePrompt(
            any(),
            any(),
            systemPrompt: any(named: 'systemPrompt'),
          )).thenThrow(Exception('Network timeout'));

      final response = await router.call(
        _request('POST', '/prompt', body: {
          'model': 'gpt-4',
          'description': 'A chill beat',
        }),
      );

      expect(response.statusCode, 500);
      final json = jsonDecode(await response.readAsString());
      expect(json['message'], 'Internal server error');
    });
  });
}
