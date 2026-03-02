import 'dart:typed_data';

/// Platform-agnostic file wrapper that works on both web and native.
/// Stores the file content as bytes instead of relying on dart:io File paths.
class PickedFile {
  final Uint8List bytes;
  final String name;

  const PickedFile({required this.bytes, required this.name});
}
