import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:studio_backend/src/crypto/request_signer.dart';
import 'package:studio_backend/src/logger/logger.dart';
import 'package:studio_backend/src/server_backends/server_backend_repository.dart';
import 'package:studio_backend/src/settings/settings_repository.dart';

/// Paths that are always handled locally and never forwarded.
const _localOnlyPrefixes = [
  'v1/health',
  'v1/peers',
  'v1/server-backends',
  'v1/settings',
  'v1/users/me',
  'v1/browse',
];

/// Middleware that forwards requests to an active remote backend.
///
/// When a remote server backend is active, non-local requests are proxied to
/// it with RSA-signed headers. If no remote is active, requests pass through
/// to local handlers.
Middleware forwardingMiddleware({
  required ServerBackendRepository serverBackendRepository,
  required SettingsRepository settingsRepository,
}) {
  return (Handler innerHandler) {
    return (Request request) async {
      // Always handle local-only paths locally.
      for (final prefix in _localOnlyPrefixes) {
        if (request.url.path.startsWith(prefix)) {
          return innerHandler(request);
        }
      }

      // Check for an active remote backend.
      final activeBackend = await serverBackendRepository.getActive();
      if (activeBackend == null) {
        return innerHandler(request);
      }

      // Forward to remote.
      final privateKeyPem = await settingsRepository.getServerPrivateKey();
      final publicKeyPem = await settingsRepository.getServerPublicKey();

      if (privateKeyPem == null || publicKeyPem == null) {
        logger.e(message: 'Server keys not found. Cannot sign forwarded request.');
        return Response.internalServerError(
          body: jsonEncode({'message': 'Server keys not configured'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final bodyBytes = Uint8List.fromList(
        await request.read().expand((chunk) => chunk).toList(),
      );
      final path = '/${request.url.path}';
      final query = request.url.query.isNotEmpty ? '?${request.url.query}' : '';

      // For signing, use the decoded string for JSON bodies and empty
      // string for binary/multipart bodies (the signature covers
      // method + path + timestamp regardless).
      final contentType = request.headers['content-type'] ?? '';
      final isJsonBody = contentType.contains('application/json');
      final bodyForSigning = isJsonBody ? utf8.decode(bodyBytes) : '';

      final signatureHeaders = signRequest(
        method: request.method,
        path: path,
        body: bodyForSigning,
        privateKeyPem: privateKeyPem,
        publicKeyPem: publicKeyPem,
      );

      // Build the remote URI.
      final scheme = activeBackend.secure ? 'https' : 'http';
      final remoteUri = Uri.parse('$scheme://${activeBackend.apiHost}$path$query');

      logger.d(message: 'Forwarding ${request.method} $path → $remoteUri');

      // Forward headers, excluding hop-by-hop headers.
      final forwardHeaders = Map<String, String>.from(request.headers)
        ..remove('host')
        ..remove('transfer-encoding')
        ..addAll(signatureHeaders);

      final client = http.Client();
      try {
        final remoteRequest = http.Request(request.method, remoteUri)
          ..headers.addAll(forwardHeaders)
          ..bodyBytes = bodyBytes;

        final streamed = await client.send(remoteRequest);
        final responseBody = await streamed.stream.toBytes();

        // Filter hop-by-hop headers from the response.
        final responseHeaders = Map<String, String>.from(streamed.headers)
          ..remove('transfer-encoding');

        return Response(
          streamed.statusCode,
          body: responseBody,
          headers: responseHeaders,
        );
      } catch (e, s) {
        logger.e(
          message: 'Failed to forward request to $remoteUri',
          error: e,
          stackTrace: s,
        );
        return Response.internalServerError(
          body: jsonEncode({'message': 'Failed to reach remote server'}),
          headers: {'Content-Type': 'application/json'},
        );
      } finally {
        client.close();
      }
    };
  };
}
