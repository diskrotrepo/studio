import 'dart:collection';

import 'package:studio_backend/src/logger/log_writer.dart';

/// An in-memory ring-buffer [LogWriter] that keeps the most recent [maxEntries]
/// log entries for retrieval via the `/logs` API endpoint.
class BufferLogWriter implements LogWriter {
  BufferLogWriter({this.maxEntries = 500});

  final int maxEntries;
  final Queue<Map<String, dynamic>> _buffer = Queue<Map<String, dynamic>>();

  @override
  void write({
    required LogType type,
    dynamic message,
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic> properties = const {},
  }) {
    final entry = <String, dynamic>{
      'severity': type.severity,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'message': message?.toString(),
      if (error != null) 'error': error.toString(),
      if (stackTrace != null) 'stackTrace': stackTrace.toString(),
      if (properties.isNotEmpty) 'properties': properties,
    };
    _buffer.addLast(entry);
    while (_buffer.length > maxEntries) {
      _buffer.removeFirst();
    }
  }

  /// Returns all buffered entries (oldest first).
  List<Map<String, dynamic>> get entries => _buffer.toList();

  /// Clears all buffered entries.
  void clear() => _buffer.clear();
}
