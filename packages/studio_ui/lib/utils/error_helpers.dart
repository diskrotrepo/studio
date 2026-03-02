import '../services/api_client.dart';

/// Converts an exception to a user-friendly message suitable for display.
///
/// [ApiException] instances use the server message if short and clean,
/// otherwise fall back to a status-code description.  Raw stack traces
/// and internal details are never exposed.
String userFriendlyError(Object error) {
  if (error is ApiException) {
    return _mapApiException(error);
  }
  if (error is FormatException || error is TypeError) {
    return 'Received an invalid response from the server.';
  }
  return 'Something went wrong. Please try again.';
}

String _mapApiException(ApiException e) {
  final msg = e.message.trim();

  if (msg.contains('Exception:') ||
      msg.contains('Traceback') ||
      msg.startsWith('{') ||
      msg.length > 300) {
    return _statusCodeMessage(e.statusCode);
  }

  if (msg.isNotEmpty) return msg;

  return _statusCodeMessage(e.statusCode);
}

String _statusCodeMessage(int code) {
  return switch (code) {
    400 => 'The request was invalid. Please check your input.',
    401 => 'Authentication required. Please log in.',
    403 => 'You do not have permission for this action.',
    404 => 'The requested resource was not found.',
    409 => 'A conflict occurred. The resource may already exist.',
    413 => 'The file is too large.',
    422 =>
      'The server could not process the request. Please check your input.',
    429 => 'Too many requests. Please wait a moment and try again.',
    >= 500 && < 600 => 'A server error occurred. Please try again later.',
    _ => 'Something went wrong (error $code).',
  };
}
