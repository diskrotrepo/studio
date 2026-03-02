// lib/radio/network/diskrot_http_client.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';


class DiskRotHttpClient {
  DiskRotHttpClient();
  final apiVersion = 'v1';
  int port = 0;

  Uri _buildUri(String endpoint, [Map<String, dynamic>? query]) {
    return Uri.http('127.0.0.1:$port', endpoint, query);
  }

  Future<http.Response> get({
    required String userId,
    required String endpoint,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(endpoint, query);
    final response = await http.get(uri, headers: headers);

    return response;
  }

  Future<http.Response> post({
    required String? userId,
    required String endpoint,
    required Map<String, dynamic> data,
    Map<String, String>? headers,
  }) async {
    if (userId == null) {
      final uri = _buildUri(endpoint);

      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(data),
      );

      return response;
    }

    final uri = _buildUri(endpoint);

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(data),
    );

    return response;
  }

  Future<http.Response> anonLogin({
    required String endpoint,
    required String clientId,
  }) async {
    final body = {'grant_type': 'anonymous', 'client_id': clientId};

    final uri = _buildUri(endpoint);

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body.entries
          .map(
            (e) =>
                '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
          )
          .join('&'),
    );

    return response;
  }

  Future<http.Response> put({
    required String userId,
    required String endpoint,
    required Map<String, dynamic> data,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(endpoint);

    final response = await http.put(
      uri,
      headers: headers,
      body: jsonEncode(data),
    );

    return response;
  }

  Future<http.Response> delete({
    String? userId,
    required String endpoint,
    Map<String, String>? headers,
  }) async {
    if (userId == null) {
      final uri = _buildUri(endpoint);
      final response = await http.delete(uri, headers: headers);
      return response;
    }

    final uri = _buildUri(endpoint);
    final response = await http.delete(uri, headers: headers);

    return response;
  }

  /// Send EXACT bytes using application/octet-stream (non-streaming convenience).
  Future<http.Response> postOctetStream({
    required String userId,
    required String endpoint,
    required Uint8List bytes,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    return http.Response('Not Implemented', 501);
  }

  Future<http.Response> postMultipart({
    required String userId,
    required String endpoint,
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    Map<String, String> fields = const {},
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(endpoint, query);

    final req = http.MultipartRequest('POST', uri)
      ..fields.addAll(fields)
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
          contentType: MediaType.parse(mimeType),
        ),
      );

    final client = http.Client();
    try {
      final streamed = await client.send(req);

      return http.Response.fromStream(streamed);
    } finally {
      client.close();
    }
  }

  Future<http.Response> putBytes({
    required String userId,
    required String endpoint,
    required Uint8List bytes,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    return http.Response('Not Implemented', 501);
  }

  Future<http.StreamedResponse> sendStreaming({
    required String userId,
    required String method, // 'POST' | 'PUT' | 'PATCH' | etc.
    required String endpoint,
    required Stream<List<int>> Function() bodyStreamFactory,
    required int contentLength,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    return http.StreamedResponse(const Stream.empty(), 501);
  }
}
