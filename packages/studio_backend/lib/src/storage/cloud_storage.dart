import 'dart:async';
import 'dart:typed_data';

abstract class CloudStorage {
  Bucket bucket(String name);
}

class MalformedObjectPathException implements Exception {}

class CloudObject {
  CloudObject({
    required this.name,
    required this.updated,
    required this.length,
  });

  final String name;
  final DateTime updated;
  final int length;
}

abstract class Bucket {
  Future<String> objectUrl(String objectName);

  Stream<List<int>> read(String objectName);

  Future<Uint8List> readBinary(String objectName);

  Future<void> delete(String objectName);

  StreamSink<List<int>> write(
    String objectName, {
    int? length,
    String? contentType,
  });

  Future<bool> exists(String objectName);

  Stream<CloudObject> list({String? prefix, String? matchGlob});
}
