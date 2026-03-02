/// Base class for per-model text clients.
///
/// Each text model gets its own subclass that acts as an anticorruption
/// layer, mapping standardized diskrot API requests to the model's
/// specific API format.
abstract class TextModelClient {
  /// Generate song lyrics from a plain-language [description].
  /// Optionally overrides the system prompt with [systemPrompt].
  Future<String> generateLyrics(String description, {String? systemPrompt});

  /// Generate an audio style/prompt description from a plain-language [description].
  /// Optionally overrides the system prompt with [systemPrompt].
  Future<String> generatePrompt(String description, {String? systemPrompt});

  /// Checks if the model endpoint is healthy.
  Future<bool> healthCheck();
}

class TextModelException implements Exception {
  TextModelException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'TextModelException($statusCode): $body';
}
