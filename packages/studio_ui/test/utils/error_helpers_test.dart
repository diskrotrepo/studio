import 'package:flutter_test/flutter_test.dart';
import 'package:studio_ui/services/api_client.dart';
import 'package:studio_ui/utils/error_helpers.dart';

void main() {
  group('userFriendlyError', () {
    test('returns clean ApiException message', () {
      final e = ApiException(400, 'Invalid field');
      expect(userFriendlyError(e), 'Invalid field');
    });

    test('filters stack-trace-like messages', () {
      final e = ApiException(500, 'Exception: NullPointerException at ...');
      final msg = userFriendlyError(e);
      expect(msg, isNot(contains('NullPointer')));
      expect(msg.toLowerCase(), contains('server error'));
    });

    test('filters messages containing Traceback', () {
      final e = ApiException(500, 'Traceback (most recent call last): ...');
      final msg = userFriendlyError(e);
      expect(msg, isNot(contains('Traceback')));
    });

    test('filters JSON-like messages', () {
      final e = ApiException(500, '{"error": "internal", "stack": "..."}');
      final msg = userFriendlyError(e);
      expect(msg, isNot(contains('internal')));
    });

    test('filters very long messages', () {
      final longMsg = 'A' * 301;
      final e = ApiException(500, longMsg);
      final msg = userFriendlyError(e);
      expect(msg.length, lessThan(301));
    });

    test('maps 401 to authentication message', () {
      final e = ApiException(401, '');
      expect(userFriendlyError(e).toLowerCase(), contains('authentication'));
    });

    test('maps 403 to permission message', () {
      final e = ApiException(403, '');
      expect(userFriendlyError(e).toLowerCase(), contains('permission'));
    });

    test('maps 404 to not found message', () {
      final e = ApiException(404, '');
      expect(userFriendlyError(e).toLowerCase(), contains('not found'));
    });

    test('maps 429 to rate limit message', () {
      final e = ApiException(429, '');
      expect(userFriendlyError(e).toLowerCase(), contains('too many'));
    });

    test('maps 5xx to server error', () {
      final e = ApiException(502, '');
      expect(userFriendlyError(e).toLowerCase(), contains('server error'));
    });

    test('handles FormatException', () {
      final msg = userFriendlyError(const FormatException('bad json'));
      expect(msg.toLowerCase(), contains('invalid response'));
    });

    test('handles TypeError', () {
      // Create a real TypeError by forcing a bad cast.
      try {
        (42 as dynamic) as String;
      } on TypeError catch (e) {
        final msg = userFriendlyError(e);
        expect(msg.toLowerCase(), contains('invalid response'));
      }
    });

    test('handles unknown exceptions', () {
      final msg = userFriendlyError(Exception('random'));
      expect(msg.toLowerCase(), contains('something went wrong'));
    });

    test('handles non-Exception objects', () {
      final msg = userFriendlyError('string error');
      expect(msg.toLowerCase(), contains('something went wrong'));
    });
  });
}
