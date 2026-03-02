import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:studio_backend/src/logger/logger.dart' show logger;
import 'package:studio_backend/src/text/text_model_client.dart';

/// Anticorruption layer for YuLan-Mini-Instruct served via vLLM.
///
/// Translates generate-lyrics / generate-prompt calls to the
/// OpenAI-compatible /v1/chat/completions endpoint exposed by vLLM.
class YuLanMiniClient extends TextModelClient {
  YuLanMiniClient({
    required String baseUrl,
    String? apiKey,
    http.Client? client,
  }) : _baseUrl = baseUrl,
       _apiKey = apiKey,
       _client = client ?? http.Client();

  final String _baseUrl;
  final String? _apiKey;
  final http.Client _client;

  /// Formats a raw prompt using YuLan-Mini's Llama-3-style chat template.
  String _formatPrompt(String system, String user) =>
      '<s>\n'
      '<|start_header_id|>system<|end_header_id|>\n'
      '$system<|eot_id|>\n'
      '<|start_header_id|>user<|end_header_id|>\n'
      '$user<|eot_id|>\n'
      '<|start_header_id|>assistant<|end_header_id|>\n';

  Future<String> _complete(String system, String user) async {
    final prompt = _formatPrompt(system, user);
    final requestBody = jsonEncode({
      'prompt': prompt,
      'n_predict': 600,
      'temperature': 0.85,
      'stop': ['<|eot_id|>', '<|start_header_id|>', '</s>'],
    });

    logger.d(message: '[YuLan] REQUEST prompt:\n$prompt');
    logger.d(message: '[YuLan] REQUEST body:\n$requestBody');

    final url = Uri.parse('$_baseUrl/completion');
    final response = await _client.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (_apiKey != null) 'Authorization': 'Bearer $_apiKey',
      },
      body: requestBody,
    );

    logger.d(message: '[YuLan] RESPONSE status: ${response.statusCode}');
    logger.d(message: '[YuLan] RESPONSE body:\n${response.body}');

    if (response.statusCode != 200) {
      throw TextModelException(response.statusCode, response.body);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final content = (data['content'] as String).trim();
    logger.d(message: '[YuLan] PARSED content:\n$content');
    return content;
  }

  static const _defaultLyricsSystemPrompt =
      'You are a creative lyricist. Write only the song lyrics in response to '
      'the user description. Output the lyrics directly with no commentary, '
      'explanation, or extra formatting.';

  static const _defaultPromptSystemPrompt =
      '''You are a music producer. Write a concise audio style description for 
      the song based on the user's input. Highlight unique styles, innovative techniques,
       and use positive adjectives to describe the genre, mood, tempo, and key instruments.
        Output the description only with no additional commentary or explanation''';

  @override
  Future<String> generateLyrics(String description, {String? systemPrompt}) =>
      _complete(systemPrompt ?? _defaultLyricsSystemPrompt, description);

  @override
  Future<String> generatePrompt(String description, {String? systemPrompt}) =>
      _complete(systemPrompt ?? _defaultPromptSystemPrompt, description);

  @override
  Future<bool> healthCheck() async {
    try {
      final url = Uri.parse('$_baseUrl/health');
      final response = await _client.get(url);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
