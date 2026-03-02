import 'package:studio_backend/src/text/text_model_client.dart';

/// Routes text generation requests to the appropriate per-model client.
class TextClient {
  TextClient({required Map<String, TextModelClient> modelClients})
      : _clients = modelClients;

  final Map<String, TextModelClient> _clients;

  /// Available model names.
  Iterable<String> get models => _clients.keys;

  /// Returns true if [model] has a registered client.
  bool hasModel(String model) => _clients.containsKey(model);

  TextModelClient _require(String model) {
    final client = _clients[model];
    if (client == null) {
      throw ArgumentError.value(model, 'model', 'Unknown text model');
    }
    return client;
  }

  Future<String> generateLyrics(
    String model,
    String description, {
    String? systemPrompt,
  }) => _require(model).generateLyrics(description, systemPrompt: systemPrompt);

  Future<String> generatePrompt(
    String model,
    String description, {
    String? systemPrompt,
  }) =>
      _require(model).generatePrompt(description, systemPrompt: systemPrompt);

  Future<bool> healthCheck(String model) async {
    final client = _clients[model];
    if (client == null) return false;
    return client.healthCheck();
  }
}
