import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'package:studio_ui/configuration/configuration_base.dart';
import 'package:studio_ui/utils/filename_sanitizer.dart';

class DiskRotHttpClient {
  DiskRotHttpClient(
    this.configuration, {
    required this.onAnonymousLoginRequired,
    http.Client Function()? httpClientFactory,
  }) : httpClientFactory = httpClientFactory ?? (() => http.Client());

  final Configuration configuration;

  final Future<void> Function() onAnonymousLoginRequired;
  final http.Client Function() httpClientFactory;
  String? userId;
  final apiVersion = 'v1';

  Uri _buildUri(String endpoint, [Map<String, dynamic>? query]) {
    return configuration.secure
        ? Uri.https(configuration.apiHost, '$apiVersion$endpoint', query)
        : Uri.http(configuration.apiHost, '$apiVersion$endpoint', query);
  }

  Map<String, String> _baseHeaders() => {
    'Accept': 'application/json',
    'Diskrot-Project-Id': configuration.applicationId,
    'Diskrot-User-Id': ?userId,
  };

  Future<http.Response> get({
    required String endpoint,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(endpoint, query);
    final client = httpClientFactory();

    try {
      return await client.get(
        uri,
        headers: {..._baseHeaders(), ...?headers},
      );
    } finally {
      client.close();
    }
  }

  Future<http.Response> post({
    required String endpoint,
    required Map<String, dynamic> data,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(endpoint);
    final client = httpClientFactory();

    try {
      return await client.post(
        uri,
        headers: {
          ..._baseHeaders(),
          'Content-Type': 'application/json',
          ...?headers,
        },
        body: jsonEncode(data),
      );
    } finally {
      client.close();
    }
  }

  Future<http.Response> put({
    required String endpoint,
    required Map<String, dynamic> data,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(endpoint);
    final client = httpClientFactory();

    try {
      return await client.put(
        uri,
        headers: {
          ..._baseHeaders(),
          'Content-Type': 'application/json',
          ...?headers,
        },
        body: jsonEncode(data),
      );
    } finally {
      client.close();
    }
  }

  Future<http.Response> patch({
    required String endpoint,
    required Map<String, dynamic> data,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(endpoint);
    final client = httpClientFactory();

    try {
      return await client.patch(
        uri,
        headers: {
          ..._baseHeaders(),
          'Content-Type': 'application/json',
          ...?headers,
        },
        body: jsonEncode(data),
      );
    } finally {
      client.close();
    }
  }

  Future<http.Response> delete({
    required String endpoint,
  }) async {
    final uri = _buildUri(endpoint);
    final client = httpClientFactory();

    try {
      return await client.delete(uri, headers: _baseHeaders());
    } finally {
      client.close();
    }
  }

  /// Send EXACT bytes using application/octet-stream (non-streaming convenience).
  Future<http.Response> postOctetStream({
    required String endpoint,
    required Uint8List bytes,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(endpoint, query);
    final client = httpClientFactory();

    try {
      final req = http.Request('POST', uri)
        ..headers.addAll({
          ..._baseHeaders(),
          'Content-Type': 'application/octet-stream',
          'Accept-Encoding': 'identity',
          ...?headers,
        })
        ..bodyBytes = bytes;
      final streamed = await client.send(req);
      return http.Response.fromStream(streamed);
    } finally {
      client.close();
    }
  }

  Future<http.Response> postMultipart({
    required String endpoint,
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    Map<String, String> fields = const {},
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(endpoint, query);
    final client = httpClientFactory();

    try {
      final req = http.MultipartRequest('POST', uri)
        ..headers.addAll({..._baseHeaders(), ...?headers})
        ..fields.addAll(fields)
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: sanitizeFilename(filename),
            contentType: MediaType.parse(mimeType),
          ),
        );
      final streamed = await client.send(req);
      return http.Response.fromStream(streamed);
    } finally {
      client.close();
    }
  }

  Future<http.Response> putBytes({
    required String endpoint,
    required Uint8List bytes,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(endpoint, query);
    final req = http.Request('PUT', uri)
      ..headers.addAll({..._baseHeaders(), ...?headers})
      ..bodyBytes = bytes;
    final client = httpClientFactory();
    try {
      final streamed = await client.send(req);
      return http.Response.fromStream(streamed);
    } finally {
      client.close();
    }
  }

  Future<http.StreamedResponse> sendStreaming({
    required String method,
    required String endpoint,
    required Stream<List<int>> Function() bodyStreamFactory,
    required int contentLength,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(endpoint, query);
    final client = httpClientFactory();

    try {
      final sreq = http.StreamedRequest(method, uri);
      sreq.headers.addAll({
        ..._baseHeaders(),
        'Accept-Encoding': 'identity',
        ...?headers,
        'Content-Length': contentLength.toString(),
      });

      await bodyStreamFactory().pipe(sreq.sink);
      await sreq.sink.close();

      return client.send(sreq);
    } finally {
      client.close();
    }
  }
}
