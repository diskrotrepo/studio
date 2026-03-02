import 'package:drift/drift.dart';
import 'package:studio_backend/src/database/database.dart';
import 'package:uuid/uuid.dart';

const defaultLyricsSystemPrompt =
    'You are a creative lyricist. Write only the song lyrics in response to '
    'the user description. Output the lyrics directly with no commentary, '
    'explanation, or extra formatting.';

const defaultPromptSystemPrompt =
    'You are a music producer. Write only a brief audio style description '
    '(genre, mood, tempo, instruments) for the song described by the user. '
    'Output the description directly with no commentary or extra text.';

class SettingsRepository {
  SettingsRepository({required Database database}) : _database = database;

  final Database _database;

  Future<String> getLyricsSystemPrompt({String? audioModel}) async {
    if (audioModel != null) {
      final modelValue =
          await _getValueOrNull('lyrics_system_prompt:$audioModel');
      if (modelValue != null) return modelValue;
    }
    return _getValue('lyrics_system_prompt',
        defaultValue: defaultLyricsSystemPrompt);
  }

  Future<String> getPromptSystemPrompt({String? audioModel}) async {
    if (audioModel != null) {
      final modelValue =
          await _getValueOrNull('prompt_system_prompt:$audioModel');
      if (modelValue != null) return modelValue;
    }
    return _getValue('prompt_system_prompt',
        defaultValue: defaultPromptSystemPrompt);
  }

  Future<Map<String, String>> getAll() async {
    final rows = await _database.select(_database.appSettings).get();
    final map = {
      'lyrics_system_prompt': defaultLyricsSystemPrompt,
      'prompt_system_prompt': defaultPromptSystemPrompt,
      'allow_peer_connections': 'false',
    };
    for (final row in rows) {
      if (row.value != null) {
        map[row.key] = row.value!;
      }
    }
    return map;
  }

  Future<void> updateAll(Map<String, String> values) async {
    for (final entry in values.entries) {
      await _setValue(entry.key, entry.value);
    }
  }

  Future<String> _getValue(String key, {required String defaultValue}) async {
    final row = await (_database.select(_database.appSettings)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value ?? defaultValue;
  }

  Future<String?> _getValueOrNull(String key) async {
    final row = await (_database.select(_database.appSettings)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  /// Return the server's external user ID, creating one if it doesn't exist.
  Future<String> ensureExternalUserId() async {
    final existing = await _getValueOrNull('external_user_id');
    if (existing != null) return existing;
    final id = const Uuid().v4();
    await _setValue('external_user_id', id);
    return id;
  }

  Future<String> getExternalUserId() async {
    final id = await _getValueOrNull('external_user_id');
    if (id == null) throw StateError('external_user_id not initialized');
    return id;
  }

  /// Whether the server accepts incoming peer connections. Default `false`.
  Future<bool> getAllowPeerConnections() async {
    final v = await _getValueOrNull('allow_peer_connections');
    return v == 'true';
  }

  Future<void> setAllowPeerConnections(bool value) async {
    await _setValue('allow_peer_connections', value.toString());
  }

  Future<String?> getServerPublicKey() => _getValueOrNull('server_public_key');

  Future<String?> getServerPrivateKey() =>
      _getValueOrNull('server_private_key');

  Future<void> setServerKeys(String publicKey, String privateKey) async {
    await _setValue('server_public_key', publicKey);
    await _setValue('server_private_key', privateKey);
  }

  /// Seed default system prompts for each audio model if they don't already
  /// exist in the database. Called once at startup.
  Future<void> ensureDefaultPrompts(List<String> audioModels) async {
    for (final model in audioModels) {
      final lyricsKey = 'lyrics_system_prompt:$model';
      final promptKey = 'prompt_system_prompt:$model';

      if (await _getValueOrNull(lyricsKey) == null) {
        await _setValue(lyricsKey, defaultLyricsSystemPrompt);
      }
      if (await _getValueOrNull(promptKey) == null) {
        await _setValue(promptKey, defaultPromptSystemPrompt);
      }
    }
  }

  Future<void> _setValue(String key, String value) async {
    await _database.appSettings.insertOnConflictUpdate(
      AppSettingsCompanion(key: Value(key), value: Value(value)),
    );
  }
}
