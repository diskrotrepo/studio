import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Save bytes to the Downloads directory (or temp as fallback).
/// Returns the path where the file was saved.
Future<String?> saveFile(Uint8List bytes, String filename) async {
  final dir = await getDownloadsDirectory() ?? await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes);
  return file.path;
}
