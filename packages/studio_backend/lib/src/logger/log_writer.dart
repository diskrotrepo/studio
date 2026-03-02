abstract class LogWriter {
  void write({
    required LogType type,
    dynamic message,
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic> properties = const {},
  });
}

enum LogType {
  error('ERROR', 6),
  warn('WARNING', 5),
  info('INFO', 4),
  debug('DEBUG', 3),
  verbose('DEBUG', 2);

  const LogType(this.severity, this.level);

  final String severity;

  final int level;
}
