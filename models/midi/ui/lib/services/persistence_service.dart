import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/generation_params.dart';
import '../models/multitrack_params.dart';
import '../models/task_status.dart';

class PersistenceService {
  static const _singleTrackKey = 'single_track_params';
  static const _multiTrackKey = 'multi_track_params';
  static const _historyKey = 'generation_history';
  static const _serverUrlKey = 'server_url';

  final SharedPreferences _prefs;

  PersistenceService(this._prefs);

  // -- Slider settings --

  void saveSingleTrackParams(GenerationParams params) {
    _prefs.setString(_singleTrackKey, jsonEncode(params.toJson()));
  }

  GenerationParams? loadSingleTrackParams() {
    final raw = _prefs.getString(_singleTrackKey);
    if (raw == null) return null;
    try {
      return GenerationParams.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  void saveMultiTrackParams(MultitrackParams params) {
    _prefs.setString(_multiTrackKey, jsonEncode(params.toJson()));
  }

  MultitrackParams? loadMultiTrackParams() {
    final raw = _prefs.getString(_multiTrackKey);
    if (raw == null) return null;
    try {
      return MultitrackParams.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // -- History --

  void saveHistory(List<TaskStatus> history) {
    final list = history.map((t) => t.toJson()).toList();
    _prefs.setString(_historyKey, jsonEncode(list));
  }

  // -- Server URL --

  void saveServerUrl(String url) {
    _prefs.setString(_serverUrlKey, url);
  }

  String? loadServerUrl() {
    return _prefs.getString(_serverUrlKey);
  }

  // -- History --

  List<TaskStatus> loadHistory() {
    final raw = _prefs.getString(_historyKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => TaskStatus.fromPersistedJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
