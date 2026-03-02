import 'package:flutter_test/flutter_test.dart';
import 'package:studio_ui/utils/validators.dart';

void main() {
  group('requiredField', () {
    test('returns null for non-empty value', () {
      expect(requiredField('hello'), isNull);
    });

    test('returns error for empty string', () {
      expect(requiredField(''), isNotNull);
    });

    test('returns error for whitespace-only', () {
      expect(requiredField('   '), isNotNull);
    });

    test('returns error for null', () {
      expect(requiredField(null), isNotNull);
    });

    test('uses custom field name in message', () {
      expect(requiredField('', fieldName: 'Title'), contains('Title'));
    });
  });

  group('intInRange', () {
    test('returns null for valid integer in range', () {
      expect(intInRange('5', min: 0, max: 10), isNull);
    });

    test('returns null for empty (optional)', () {
      expect(intInRange('', min: 0, max: 10), isNull);
    });

    test('returns null for null (optional)', () {
      expect(intInRange(null, min: 0, max: 10), isNull);
    });

    test('returns error for non-integer', () {
      expect(intInRange('abc', min: 0, max: 10), isNotNull);
    });

    test('returns error for below min', () {
      expect(intInRange('-1', min: 0, max: 10), isNotNull);
    });

    test('returns error for above max', () {
      expect(intInRange('11', min: 0, max: 10), isNotNull);
    });

    test('accepts min boundary', () {
      expect(intInRange('0', min: 0, max: 10), isNull);
    });

    test('accepts max boundary', () {
      expect(intInRange('10', min: 0, max: 10), isNull);
    });
  });

  group('positiveDouble', () {
    test('returns null for positive value', () {
      expect(positiveDouble('1.5'), isNull);
    });

    test('returns null for empty', () {
      expect(positiveDouble(''), isNull);
    });

    test('returns error for zero', () {
      expect(positiveDouble('0'), isNotNull);
    });

    test('returns error for negative', () {
      expect(positiveDouble('-1.0'), isNotNull);
    });

    test('returns error for non-numeric', () {
      expect(positiveDouble('abc'), isNotNull);
    });
  });

  group('nonNegativeDouble', () {
    test('returns null for positive', () {
      expect(nonNegativeDouble('1.0'), isNull);
    });

    test('returns null for zero', () {
      expect(nonNegativeDouble('0'), isNull);
    });

    test('returns null for empty', () {
      expect(nonNegativeDouble(''), isNull);
    });

    test('returns error for negative', () {
      expect(nonNegativeDouble('-0.5'), isNotNull);
    });

    test('returns error for non-numeric', () {
      expect(nonNegativeDouble('xyz'), isNotNull);
    });
  });

  group('minutesField', () {
    test('returns null for valid minutes', () {
      expect(minutesField('30'), isNull);
    });

    test('returns error for negative', () {
      expect(minutesField('-1'), isNotNull);
    });

    test('returns error for above 999', () {
      expect(minutesField('1000'), isNotNull);
    });
  });

  group('secondsField', () {
    test('returns null for valid seconds', () {
      expect(secondsField('30'), isNull);
    });

    test('returns null for 0', () {
      expect(secondsField('0'), isNull);
    });

    test('returns null for 59', () {
      expect(secondsField('59'), isNull);
    });

    test('returns error for 60', () {
      expect(secondsField('60'), isNotNull);
    });

    test('returns error for negative', () {
      expect(secondsField('-1'), isNotNull);
    });
  });

  group('seedField', () {
    test('returns null for valid seed', () {
      expect(seedField('42'), isNull);
    });

    test('returns null for zero', () {
      expect(seedField('0'), isNull);
    });

    test('returns null for empty (optional)', () {
      expect(seedField(''), isNull);
    });

    test('returns error for non-integer', () {
      expect(seedField('abc'), isNotNull);
    });

    test('returns error for negative', () {
      expect(seedField('-1'), isNotNull);
    });

    test('returns error for float', () {
      expect(seedField('1.5'), isNotNull);
    });
  });

  group('bpmField', () {
    test('returns null for valid BPM', () {
      expect(bpmField('120'), isNull);
    });

    test('returns error for 0', () {
      expect(bpmField('0'), isNotNull);
    });

    test('returns error for 1000', () {
      expect(bpmField('1000'), isNotNull);
    });

    test('returns null for empty', () {
      expect(bpmField(''), isNull);
    });
  });

  group('hostField', () {
    test('returns null for valid hostname', () {
      expect(hostField('api.example.com'), isNull);
    });

    test('returns null for hostname with port', () {
      expect(hostField('api.example.com:8080'), isNull);
    });

    test('returns null for localhost with port', () {
      expect(hostField('localhost:8080'), isNull);
    });

    test('returns null for IP address', () {
      expect(hostField('192.168.1.1'), isNull);
    });

    test('returns error for empty', () {
      expect(hostField(''), isNotNull);
    });

    test('returns error for null', () {
      expect(hostField(null), isNotNull);
    });

    test('returns error for URL with path', () {
      expect(hostField('example.com/path'), isNotNull);
    });

    test('returns error for URL with backslash', () {
      expect(hostField('example.com\\path'), isNotNull);
    });

    test('returns error for URL with spaces', () {
      expect(hostField('example .com'), isNotNull);
    });
  });
}
