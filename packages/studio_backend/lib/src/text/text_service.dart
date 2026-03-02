import 'dart:convert';

import 'package:studio_backend/src/logger/logger.dart' show logger;
import 'package:studio_backend/src/settings/settings_repository.dart';
import 'package:studio_backend/src/text/text_client.dart';
import 'package:studio_backend/src/utils/shelf_helper.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class TextService {
  TextService({
    required TextClient textClient,
    required SettingsRepository settingsRepository,
  }) : _client = textClient,
       _settings = settingsRepository;

  final TextClient _client;
  final SettingsRepository _settings;

  Router get router {
    final r = Router();
    r.post('/lyrics', _generateLyrics);
    r.post('/prompt', _generatePrompt);
    return r;
  }

  Future<Response> _generateLyrics(Request request) async {
    final body =
        jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final model = (body['model'] as String?)?.trim();
    final description = (body['description'] as String?)?.trim();

    if (model == null || model.isEmpty) {
      return jsonErr(400, {'message': 'model is required'});
    }
    if (description == null || description.isEmpty) {
      return jsonErr(400, {'message': 'description is required'});
    }
    final lengthErr = validateMaxLength(description, 'description');
    if (lengthErr != null) {
      return jsonErr(400, {'message': lengthErr});
    }
    if (!_client.hasModel(model)) {
      return jsonErr(400, {
        'message': 'Unknown model: $model',
        'available_models': _client.models.toList(),
      });
    }

    try {
      final audioModel = (body['audio_model'] as String?)?.trim();
      final systemPrompt =
          await _settings.getLyricsSystemPrompt(audioModel: audioModel);
      final lyrics = await _client.generateLyrics(
        model,
        description,
        systemPrompt: systemPrompt,
      );
      return jsonOk({'lyrics': lyrics});
    } catch (e) {
      logger.e(message: 'Lyrics generation failed', error: e);
      return jsonErr(500, {'message': 'Internal server error'});
    }
  }

  Future<Response> _generatePrompt(Request request) async {
    final body =
        jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final model = (body['model'] as String?)?.trim();
    final description = (body['description'] as String?)?.trim();

    if (model == null || model.isEmpty) {
      return jsonErr(400, {'message': 'model is required'});
    }
    if (description == null || description.isEmpty) {
      return jsonErr(400, {'message': 'description is required'});
    }
    final lengthErr = validateMaxLength(description, 'description');
    if (lengthErr != null) {
      return jsonErr(400, {'message': lengthErr});
    }
    if (!_client.hasModel(model)) {
      return jsonErr(400, {
        'message': 'Unknown model: $model',
        'available_models': _client.models.toList(),
      });
    }

    try {
      final audioModel = (body['audio_model'] as String?)?.trim();
      final systemPrompt =
          await _settings.getPromptSystemPrompt(audioModel: audioModel);
      final prompt = await _client.generatePrompt(
        model,
        description,
        systemPrompt: systemPrompt,
      );
      return jsonOk({'prompt': prompt});
    } catch (e) {
      logger.e(message: 'Prompt generation failed', error: e);
      return jsonErr(500, {'message': 'Internal server error'});
    }
  }
}
