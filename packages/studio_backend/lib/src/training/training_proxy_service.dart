import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:studio_backend/src/logger/logger.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// Transparent proxy that forwards `/v1/dataset/*` and `/v1/training/*`
/// requests to the ACE-Step Python server.
class TrainingProxyService {
  TrainingProxyService({required this.baseUrl, this.apiKey});

  final String baseUrl;
  final String? apiKey;

  Router get datasetRouter {
    final router = Router();
    router.all('/<path|.+>', (Request request, String path) {
      return _proxy(request, '/v1/dataset/$path');
    });
    return router;
  }

  Router get trainingRouter {
    final router = Router();
    router.all('/<path|.+>', (Request request, String path) {
      return _proxy(request, '/v1/training/$path');
    });
    return router;
  }

  Future<Response> _proxy(Request request, String remotePath) async {
    final query =
        request.url.query.isNotEmpty ? '?${request.url.query}' : '';
    final remoteUri = Uri.parse('$baseUrl$remotePath$query');

    logger.d(
      message:
          'Training proxy: ${request.method} ${request.url.path} -> $remoteUri',
    );

    final bodyBytes = Uint8List.fromList(
      await request.read().expand((chunk) => chunk).toList(),
    );

    final forwardHeaders = Map<String, String>.from(request.headers)
      ..remove('host')
      ..remove('transfer-encoding');

    if (apiKey != null) {
      forwardHeaders['Authorization'] = 'Bearer $apiKey';
    }

    final client = http.Client();
    try {
      final remoteRequest = http.Request(request.method, remoteUri)
        ..headers.addAll(forwardHeaders)
        ..bodyBytes = bodyBytes;

      final streamed = await client.send(remoteRequest);
      final responseBody = await streamed.stream.toBytes();

      final responseHeaders = Map<String, String>.from(streamed.headers)
        ..remove('transfer-encoding');

      // The Python server always returns HTTP 200 and puts the real status
      // in a "code" field inside the JSON body.  Translate that to the HTTP
      // status code so the Flutter client's statusCode checks work.
      var statusCode = streamed.statusCode;
      if (statusCode == 200) {
        try {
          final json =
              jsonDecode(utf8.decode(responseBody)) as Map<String, dynamic>;
          final appCode = json['code'] as int?;
          if (appCode != null && appCode != 200) {
            statusCode = appCode;
          }
        } catch (_) {
          // Not JSON or missing code – keep original status.
        }
      }

      return Response(
        statusCode,
        body: responseBody,
        headers: responseHeaders,
      );
    } catch (e) {
      logger.e(
        message: 'Training proxy: failed to reach $remoteUri',
        error: e,
      );
      return Response.internalServerError(
        body: jsonEncode({'message': 'Failed to reach model server'}),
        headers: {'Content-Type': 'application/json'},
      );
    } finally {
      client.close();
    }
  }
}
