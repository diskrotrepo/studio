import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:studio_backend/src/storage/cloud_storage.dart';
import 'package:path/path.dart' as path;

class LocalStorage implements CloudStorage {
  LocalStorage();

  @override
  Bucket bucket(String name) {
    final root = Platform.environment['DISKROT_STORAGE_ROOT']?.trim() ?? '.';
    return LocalBucket(bucket: path.join(root, name));
  }
}

class LocalObjectInfo implements CloudObject {
  LocalObjectInfo({required File file}) : _file = file;

  final File _file;

  @override
  int get length => _file.lengthSync();

  @override
  String get name => _file.path.split(Platform.pathSeparator).last;

  @override
  DateTime get updated => _file.lastModifiedSync();
}

class LocalBucket implements Bucket {
  LocalBucket({required String bucket}) : _bucket = bucket;

  final String _bucket;

  Future<void> compose({
    required List<String> objects,
    required String destination,
    required String contentType,
  }) async {
    final directory = Directory(_bucket);
    final destFile = File('${directory.path}/$destination');
    for (final object in objects) {
      final file = File('${directory.path}/$object');
      destFile.writeAsBytesSync(file.readAsBytesSync(), mode: FileMode.append);
    }
  }


  Future<String> createDownloadLink({
    required String object,
    required String serviceAccountEmail,
    Duration expiration = const Duration(hours: 1),
  }) async {
    final directory = Directory(_bucket);

    if (!directory.existsSync()) {
      return '';
    }

    final file = File('${directory.path}/$object');

    if (!file.existsSync()) {
      return '';
    }

    return 'file:/${directory.path}/$object';
  }

  @override
  Future<bool> exists(String objectName) async {
    final directory = Directory(_bucket);
    final file = File('${directory.path}/$objectName');
    return file.existsSync();
  }

  @override
  Stream<CloudObject> list({String? prefix, String? matchGlob}) async* {
    final directory = Directory(_bucket);

    if (!directory.existsSync()) {
      return;
    }

    await for (final entity in directory.list()) {
      if (entity is File &&
          entity.path.split(Platform.pathSeparator).last != '.DS_Store') {
        yield LocalObjectInfo(file: entity);
      }
    }
  }

  @override
  Stream<List<int>> read(String objectName) {
    final directory = Directory(_bucket);
    final file = File('${directory.path}/$objectName');
    return file.openRead();
  }

  @override
  StreamSink<List<int>> write(
    String objectName, {
    int? length,
    String? contentType,
  }) {
    final extractDirectory = _extractDirectory(objectName);
    final extractedObjectName = path.basename(objectName);
    final Directory directory;

    if (extractDirectory.isNotEmpty) {
      directory = Directory(path.join(_bucket, extractDirectory));
    } else {
      directory = Directory(_bucket);
    }

    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    final fileName = '${directory.path}/$extractedObjectName';
    final file = File(fileName);

    final sink = file.openWrite();
    return sink;
  }

  String _extractDirectory(String filePath) {
    if (path.isAbsolute(filePath) || filePath.contains(path.separator)) {
      return path.dirname(filePath);
    }

    return '';
  }

  @override
  Future<String> objectUrl(String objectName) async {
    return await createDownloadLink(
      object: objectName,
      serviceAccountEmail: '',
    );
  }

  @override
  Future<void> delete(String objectName) async {
    final path = objectName.replaceFirst('file:/', '');
    final file = File(path);
    await file.delete();
  }

  @override
  Future<Uint8List> readBinary(String objectName) async {
    final stream = read(objectName);
    final bytes = await stream.fold<List<int>>(
      [],
      (previous, element) => previous..addAll(element),
    );
    return Uint8List.fromList(bytes);
  }
}
