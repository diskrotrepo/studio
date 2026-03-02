import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:studio_backend/src/crypto/request_signer.dart';
import 'package:studio_backend/src/peers/peer_repository.dart';
import 'package:studio_backend/src/settings/settings_repository.dart';

/// Middleware that verifies RSA-signed requests.
///
/// If signature headers (`X-Signature`, `X-Public-Key`, `X-Timestamp`) are
/// present, the signature is verified. Invalid signatures return 401.
/// Requests without signature headers pass through unchanged (local UI calls).
///
/// When a [peerRepository] is provided, verified peers are tracked and
/// blocked peers are rejected with 403.
///
/// When [settingsRepository] is provided, incoming peer requests are rejected
/// with 403 if the `allow_peer_connections` setting is not `true`.
Middleware signatureVerificationMiddleware({
  required PeerRepository peerRepository,
  required SettingsRepository settingsRepository,
}) {
  return (Handler innerHandler) {
    return (Request request) async {
      final signature = request.headers['X-Signature'];
      final publicKey = request.headers['X-Public-Key'];
      final timestamp = request.headers['X-Timestamp'];

      // No signature headers → local request, pass through.
      if (signature == null && publicKey == null && timestamp == null) {
        return innerHandler(request);
      }

      // Reject all peer requests when connections are disabled.
      if (!await settingsRepository.getAllowPeerConnections()) {
        return Response(
          403,
          body: jsonEncode({'message': 'Peer connections are disabled'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Partial headers → malformed signed request.
      if (signature == null || publicKey == null || timestamp == null) {
        return Response(
          401,
          body: jsonEncode({'message': 'Incomplete signature headers'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Read the body for verification, then reconstruct the request.
      final body = await request.readAsString();

      final valid = verifyRequest(
        method: request.method,
        path: '/${request.url.path}',
        body: body,
        signatureBase64: signature,
        publicKeyBase64: publicKey,
        timestamp: timestamp,
      );

      if (!valid) {
        return Response(
          401,
          body: jsonEncode({'message': 'Invalid or expired signature'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Check if the peer is blocked.
      if (await peerRepository.isBlocked(publicKey)) {
        return Response(
          403,
          body: jsonEncode({'message': 'Peer is blocked'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Track the peer connection.
      await peerRepository.upsert(publicKey);

      // Reconstruct request with the body so downstream handlers can read it.
      final updatedRequest = request.change(body: body);
      return innerHandler(updatedRequest);
    };
  };
}
