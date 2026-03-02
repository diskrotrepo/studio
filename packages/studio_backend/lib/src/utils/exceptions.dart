/// Exception thrown when an invalid cursor string is provided for pagination
class InvalidCursorException implements Exception {
  const InvalidCursorException(this.message);

  final String message;

  @override
  String toString() => 'InvalidCursorException: $message';
}
