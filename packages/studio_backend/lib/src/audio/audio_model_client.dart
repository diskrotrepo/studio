import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:studio_backend/src/logger/logger.dart';

/// Base class for per-model audio clients.
///
/// Each audio model gets its own subclass that acts as an anticorruption
/// layer, mapping standardized diskrot API field names to the model's
/// specific field names.
abstract class AudioModelClient {
  AudioModelClient({
    required String baseUrl,
    String? apiKey,
    http.Client? client,
  }) : _baseUrl = baseUrl,
       _apiKey = apiKey,
       _client = client ?? http.Client();

  final String _baseUrl;
  final String? _apiKey;

  String get baseUrl => _baseUrl;
  final http.Client _client;

  /// Supported task types, parameters, and feature flags for this model.
  ///
  /// Returns a map with keys:
  ///   - `task_types`: `List<String>` of supported task types
  ///   - `parameters`: `List<String>` of supported parameter names
  ///     (standardized diskrot field names, NOT model-specific)
  ///   - `features`: `Map<String, bool>` for high-level feature flags
  Map<String, dynamic> get capabilities;

  /// Default parameter values for this model, including sample lyrics/prompt.
  Map<String, dynamic> get defaults;

  /// Translates [payload] from standardized diskrot fields to
  /// model-specific fields and submits the request.
  Future<Map<String, dynamic>> submit(
    String taskType,
    Map<String, dynamic> payload, {
    required String userId,
  });

  // ---------------------------------------------------------------------------
  // LoRA – override in subclasses that support it.
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getLoraList() =>
      throw AudioModelException(400, '$runtimeType does not support LoRA');

  Future<Map<String, dynamic>> getLoraStatus() =>
      throw AudioModelException(400, '$runtimeType does not support LoRA');

  Future<Map<String, dynamic>> loadLora(
    String loraPath, {
    String? adapterName,
  }) => throw AudioModelException(400, '$runtimeType does not support LoRA');

  Future<Map<String, dynamic>> unloadLora() =>
      throw AudioModelException(400, '$runtimeType does not support LoRA');

  Future<Map<String, dynamic>> toggleLora(bool useLora) =>
      throw AudioModelException(400, '$runtimeType does not support LoRA');

  Future<Map<String, dynamic>> setLoraScale(
    double scale, {
    String? adapterName,
  }) => throw AudioModelException(400, '$runtimeType does not support LoRA');

  // ---------------------------------------------------------------------------

  /// Checks if the model endpoint is healthy.
  Future<bool> healthCheck() async {
    try {
      final url = Uri.parse(_baseUrl).replace(path: '/health');
      final resp = await _client.get(url);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// GETs [path] on this model's endpoint.
  Future<Map<String, dynamic>> getRequest(String path) async {
    final url = Uri.parse('$_baseUrl$path');
    logger.i(message: '[$runtimeType] GET $url');

    final resp = await _client.get(
      url,
      headers: {if (_apiKey != null) 'Authorization': 'Bearer $_apiKey'},
    );

    logger.i(message: '[$runtimeType] GET $url -> ${resp.statusCode}');
    if (resp.statusCode != 200) {
      logger.e(message: '[$runtimeType] GET $url failed: ${resp.body}');
      throw AudioModelException(resp.statusCode, resp.body);
    }

    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// Posts [body] to [path] on this model's endpoint.
  /// Subclasses call this after mapping fields.
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse('$_baseUrl$path');
    logger.i(message: '[$runtimeType] POST $url');

    final resp = await _client.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (_apiKey != null) 'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode(body),
    );

    logger.i(message: '[$runtimeType] POST $url -> ${resp.statusCode}');
    if (resp.statusCode != 200) {
      logger.e(message: '[$runtimeType] POST $url failed: ${resp.body}');
      throw AudioModelException(resp.statusCode, resp.body);
    }

    return jsonDecode(resp.body) as Map<String, dynamic>;
  }
}

class AudioModelException implements Exception {
  AudioModelException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'AudioModelException($statusCode): $body';
}
