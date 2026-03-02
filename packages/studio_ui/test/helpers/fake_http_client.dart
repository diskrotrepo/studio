import 'dart:convert';

import 'package:http/http.dart' as http;

/// A configurable fake [http.Client] for unit tests.
///
/// Set [nextResponse] before each call, or provide a [handler] function
/// for more complex scenarios.
class FakeHttpClient extends http.BaseClient {
  http.Response? nextResponse;

  /// Records the last request for assertion.
  http.BaseRequest? lastRequest;

  /// Optional handler for dynamic responses.
  http.Response Function(http.BaseRequest request)? handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request;

    final response = handler?.call(request) ?? nextResponse;
    if (response == null) {
      throw StateError('FakeHttpClient: no response configured');
    }

    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }

  /// Convenience: set up a 200 JSON response.
  void respondJson(Map<String, dynamic> body, {int statusCode = 200}) {
    nextResponse = http.Response(
      jsonEncode(body),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
  }

  /// Convenience: set up an error response.
  void respondError(int statusCode, {String message = 'Error'}) {
    nextResponse = http.Response(
      jsonEncode({'message': message}),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
  }
}
