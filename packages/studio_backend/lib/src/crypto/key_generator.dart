import 'dart:math';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:pointycastle/export.dart';

class ServerKeyPair {
  const ServerKeyPair({required this.publicKeyPem, required this.privateKeyPem});

  final String publicKeyPem;
  final String privateKeyPem;
}

ServerKeyPair generateRsaKeyPair({int bitLength = 2048}) {
  final secureRandom = FortunaRandom();
  final random = Random.secure();
  final seeds = List<int>.generate(32, (_) => random.nextInt(256));
  secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));

  final keyGen = RSAKeyGenerator()
    ..init(
      ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.parse('65537'), bitLength, 64),
        secureRandom,
      ),
    );

  final pair = keyGen.generateKeyPair();
  final publicKey = pair.publicKey;
  final privateKey = pair.privateKey;

  return ServerKeyPair(
    publicKeyPem: CryptoUtils.encodeRSAPublicKeyToPem(publicKey),
    privateKeyPem: CryptoUtils.encodeRSAPrivateKeyToPem(privateKey),
  );
}
