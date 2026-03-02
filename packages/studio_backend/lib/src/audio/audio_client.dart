import 'package:studio_backend/src/audio/audio_model_client.dart';

/// Routes audio generation requests to the appropriate per-model client.
class AudioClient {
  AudioClient({
    required Map<String, AudioModelClient> modelClients,
    Set<String> disabledModels = const {},
  }) : _clients = modelClients,
       _disabledModels = disabledModels;

  final Map<String, AudioModelClient> _clients;
  final Set<String> _disabledModels;

  /// Available model names.
  Iterable<String> get models => _clients.keys;

  /// Returns true if [model] has a registered client.
  bool hasModel(String model) => _clients.containsKey(model);

  /// Returns the base URL for [model], or null if the model is not registered.
  String? baseUrlFor(String model) => _clients[model]?.baseUrl;

  /// Delegates [payload] to the model-specific client for field mapping
  /// and submission.
  ///
  /// Throws [ArgumentError] if [model] is not registered.
  Future<Map<String, dynamic>> submit(
    String model,
    Map<String, dynamic> payload, {
    required String userId,
  }) async {
    final client = _clients[model];
    if (client == null) {
      throw ArgumentError.value(model, 'model', 'Unknown model');
    }
    if (_disabledModels.contains(model)) {
      throw ArgumentError.value(model, 'model', 'Model is currently disabled');
    }

    final taskType = payload['task_type'] as String;
    final fields = Map<String, dynamic>.of(payload)..remove('task_type');

    return client.submit(taskType, fields, userId: userId);
  }

  /// Checks health of the endpoint for [model].
  Future<bool> healthCheck(String model) async {
    final client = _clients[model];
    if (client == null) return false;
    return client.healthCheck();
  }

  // ---------------------------------------------------------------------------
  // Defaults
  // ---------------------------------------------------------------------------

  /// Returns the defaults for [model], or null if not registered.
  Map<String, dynamic>? getDefaults(String model) {
    final client = _clients[model];
    if (client == null) return null;
    return client.defaults;
  }

  // ---------------------------------------------------------------------------
  // Capabilities
  // ---------------------------------------------------------------------------

  /// Returns the capabilities for [model], or null if not registered.
  Map<String, dynamic>? getCapabilities(String model) {
    final client = _clients[model];
    if (client == null) return null;
    return {
      'model': model,
      'enabled': !_disabledModels.contains(model),
      ...client.capabilities,
    };
  }

  /// Returns capabilities for all registered models.
  List<Map<String, dynamic>> getAllCapabilities() {
    return _clients.entries
        .map((e) => {
          'model': e.key,
          'enabled': !_disabledModels.contains(e.key),
          ...e.value.capabilities,
        })
        .toList();
  }

  // ---------------------------------------------------------------------------
  // LoRA
  // ---------------------------------------------------------------------------

  AudioModelClient _requireClient(String model) {
    final client = _clients[model];
    if (client == null) {
      throw ArgumentError.value(model, 'model', 'Unknown model');
    }
    return client;
  }

  Future<Map<String, dynamic>> getLoraList(String model) =>
      _requireClient(model).getLoraList();

  Future<Map<String, dynamic>> getLoraStatus(String model) =>
      _requireClient(model).getLoraStatus();

  Future<Map<String, dynamic>> loadLora(
    String model,
    String loraPath, {
    String? adapterName,
  }) => _requireClient(model).loadLora(loraPath, adapterName: adapterName);

  Future<Map<String, dynamic>> unloadLora(String model) =>
      _requireClient(model).unloadLora();

  Future<Map<String, dynamic>> toggleLora(String model, bool useLora) =>
      _requireClient(model).toggleLora(useLora);

  Future<Map<String, dynamic>> setLoraScale(
    String model,
    double scale, {
    String? adapterName,
  }) => _requireClient(model).setLoraScale(scale, adapterName: adapterName);
}
