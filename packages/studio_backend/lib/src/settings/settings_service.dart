import 'dart:convert';

import 'package:studio_backend/src/settings/settings_repository.dart';
import 'package:studio_backend/src/utils/shelf_helper.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class SettingsService {
  SettingsService({required SettingsRepository settingsRepository})
      : _repository = settingsRepository;

  final SettingsRepository _repository;

  Router get router {
    final r = Router();
    r.get('/', _getSettings);
    r.put('/', _updateSettings);
    return r;
  }

  Future<Response> _getSettings(Request request) async {
    final settings = await _repository.getAll();
    return jsonOk(settings);
  }

  static const _baseKeys = {
    'lyrics_system_prompt',
    'prompt_system_prompt',
    'allow_peer_connections',
    'visualizer_type',
  };

  static bool _isAllowedKey(String key) {
    if (_baseKeys.contains(key)) return true;
    final colon = key.indexOf(':');
    if (colon > 0 && _baseKeys.contains(key.substring(0, colon))) return true;
    return false;
  }

  Future<Response> _updateSettings(Request request) async {
    final body =
        jsonDecode(await request.readAsString()) as Map<String, dynamic>;

    final updates = <String, String>{};
    for (final entry in body.entries) {
      if (!_isAllowedKey(entry.key)) continue;
      final value = entry.value as String?;
      if (value != null) {
        final lengthErr =
            validateMaxLength(value, entry.key, maxLength: 50000);
        if (lengthErr != null) {
          return jsonErr(400, {'message': lengthErr});
        }
        updates[entry.key] = value;
      }
    }

    if (updates.isEmpty) {
      return jsonErr(400, {'message': 'No valid settings provided'});
    }

    await _repository.updateAll(updates);
    return jsonOk({'success': true});
  }
}
