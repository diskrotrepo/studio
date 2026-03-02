import 'dart:convert';
import 'dart:io';

import 'package:studio_backend/src/logger/log_writer.dart';

class ConsoleLogWriter implements LogWriter {
  @override
  void write({
    required LogType type,
    dynamic message,
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic> properties = const {},
  }) {

    final timestamp = DateTime.now().toUtc().toIso8601String();

    final Map<String, dynamic> logEntry = <String, dynamic>{
      'severity': type.severity, // Cloud Logging reads this
      'timestamp': timestamp,
      'message': message?.toString(),
      if (error != null) 'error': error.toString(),
      if (stackTrace != null) 'stackTrace': stackTrace.toString(),
      if (properties.isNotEmpty) 'properties': properties,
    };

    // One JSON object per line, no extra text.
    stdout.writeln(jsonEncode(logEntry));
  }
}
