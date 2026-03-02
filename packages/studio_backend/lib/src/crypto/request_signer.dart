import 'dart:convert';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:pointycastle/export.dart';

/// Signs an outbound request and returns the headers to attach.
///
/// The signed message is: `"$method\n$path\n$timestamp\n$body"`.
Map<String, String> signRequest({
  required String method,
  required String path,
  required String body,
  required String privateKeyPem,
  required String publicKeyPem,
}) {
  final timestamp =
      (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
  final message = '$method\n$path\n$timestamp\n$body';

  final privateKey = CryptoUtils.rsaPrivateKeyFromPem(privateKeyPem);

  final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
  signer.init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));

  final signature =
      signer.generateSignature(Uint8List.fromList(utf8.encode(message)));

  return {
    'X-Signature': base64Encode(signature.bytes),
    'X-Public-Key': base64Encode(utf8.encode(publicKeyPem)),
    'X-Timestamp': timestamp,
  };
}

/// Verifies an incoming signed request.
///
/// Returns `true` if the signature is valid and the timestamp is within
/// [maxAgeSeconds] of the current time.
bool verifyRequest({
  required String method,
  required String path,
  required String body,
  required String signatureBase64,
  required String publicKeyBase64,
  required String timestamp,
  int maxAgeSeconds = 300,
}) {
  // Replay protection: reject timestamps older than maxAgeSeconds.
  final ts = int.tryParse(timestamp);
  if (ts == null) return false;

  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  if ((now - ts).abs() > maxAgeSeconds) return false;

  final message = '$method\n$path\n$timestamp\n$body';

  final publicKeyPem = utf8.decode(base64Decode(publicKeyBase64));
  final publicKey = CryptoUtils.rsaPublicKeyFromPem(publicKeyPem);

  final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
  signer.init(false, PublicKeyParameter<RSAPublicKey>(publicKey));

  final signatureBytes = base64Decode(signatureBase64);

  try {
    return signer.verifySignature(
      Uint8List.fromList(utf8.encode(message)),
      RSASignature(Uint8List.fromList(signatureBytes)),
    );
  } catch (_) {
    return false;
  }
}
