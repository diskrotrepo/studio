import 'package:shelf/shelf.dart';
import 'package:studio_backend/src/utils/shelf_helper.dart';
import 'package:test/test.dart';

Request _request({Map<String, String>? headers}) {
  return Request(
    'GET',
    Uri.parse('http://localhost/test'),
    headers: headers,
  );
}

void main() {
  group('RequestAuth', () {
    group('userId', () {
      test('returns header value when Diskrot-User-Id is present', () {
        final request = _request(headers: {'Diskrot-User-Id': 'user-42'});
        expect(request.userId, 'user-42');
      });

      test('defaults to 1 when header is missing', () {
        final request = _request();
        expect(request.userId, '1');
      });
    });

    group('isAdmin', () {
      test('returns true for local requests without signature headers', () {
        final request = _request();
        expect(request.isAdmin, isTrue);
      });

      test('returns false when X-Signature header is present', () {
        final request = _request(headers: {'X-Signature': 'abc'});
        expect(request.isAdmin, isFalse);
      });

      test('returns false when X-Public-Key header is present', () {
        final request = _request(headers: {'X-Public-Key': 'key123'});
        expect(request.isAdmin, isFalse);
      });
    });

    group('applicationId', () {
      test('returns header value when Diskrot-Project-Id is present', () {
        final request =
            _request(headers: {'Diskrot-Project-Id': 'my-project'});
        expect(request.applicationId, 'my-project');
      });

      test('defaults to diskrot-studio when header is missing', () {
        final request = _request();
        expect(request.applicationId, 'diskrot-studio');
      });
    });

    group('projectId', () {
      test('always returns diskrot-studio', () {
        final request = _request();
        expect(request.projectId, 'diskrot-studio');
      });
    });

    group('isAnonymous', () {
      test('always returns false', () {
        final request = _request();
        expect(request.isAnonymous, isFalse);
      });
    });
  });

  group('validateMaxLength', () {
    test('returns null for null value', () {
      expect(validateMaxLength(null, 'name'), isNull);
    });

    test('returns null when value is within limit', () {
      expect(validateMaxLength('hello', 'name'), isNull);
    });

    test('returns null when value is exactly at limit', () {
      final value = 'a' * 10000;
      expect(validateMaxLength(value, 'name'), isNull);
    });

    test('returns error message when value exceeds limit', () {
      final value = 'a' * 10001;
      expect(
        validateMaxLength(value, 'description'),
        'description exceeds maximum length of 10000 characters',
      );
    });

    test('uses custom maxLength', () {
      expect(validateMaxLength('abcdef', 'title', maxLength: 5),
          'title exceeds maximum length of 5 characters');
    });

    test('returns null when value is within custom maxLength', () {
      expect(validateMaxLength('abc', 'title', maxLength: 5), isNull);
    });
  });
}
