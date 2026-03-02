import 'dart:convert';

import 'package:studio_backend/src/utils/shelf_helper.dart';
import 'package:test/test.dart';

void main() {
  group('jsonOk', () {
    test('returns 200 with JSON body', () {
      final response = jsonOk({'key': 'value'});

      expect(response.statusCode, 200);
      expect(response.headers['Content-Type'], 'application/json');
    });

    test('encodes body as JSON string', () async {
      final response = jsonOk({'count': 42});
      final body = jsonDecode(await response.readAsString());

      expect(body['count'], 42);
    });

    test('includes extra headers', () {
      final response = jsonOk(
        {'ok': true},
        extraHeaders: {'X-Custom': 'header-value'},
      );

      expect(response.headers['X-Custom'], 'header-value');
      expect(response.headers['Content-Type'], 'application/json');
    });
  });

  group('jsonErr', () {
    test('returns specified status with JSON body', () async {
      final response = jsonErr(400, {'message': 'bad request'});

      expect(response.statusCode, 400);
      expect(response.headers['Content-Type'], 'application/json');

      final body = jsonDecode(await response.readAsString());
      expect(body['message'], 'bad request');
    });

    test('supports various status codes', () {
      expect(jsonErr(404, {}).statusCode, 404);
      expect(jsonErr(500, {}).statusCode, 500);
      expect(jsonErr(422, {}).statusCode, 422);
    });

    test('includes extra headers', () {
      final response = jsonErr(
        500,
        {'error': true},
        extraHeaders: {'X-Request-Id': 'abc'},
      );

      expect(response.headers['X-Request-Id'], 'abc');
    });
  });

  group('dispositionParam', () {
    test('extracts unquoted param', () {
      const header = 'attachment; filename=song.mp3';
      expect(dispositionParam(header, 'filename'), 'song.mp3');
    });

    test('extracts quoted param', () {
      const header = 'attachment; filename="my song.mp3"';
      expect(dispositionParam(header, 'filename'), 'my song.mp3');
    });

    test('returns null for missing param', () {
      const header = 'attachment; filename=song.mp3';
      expect(dispositionParam(header, 'size'), isNull);
    });

    test('returns null for null header', () {
      expect(dispositionParam(null, 'filename'), isNull);
    });

    test('handles case-insensitive param names', () {
      const header = 'attachment; FileName="test.wav"';
      expect(dispositionParam(header, 'filename'), 'test.wav');
    });
  });

  group('parseLimit', () {
    test('returns default when not provided', () {
      expect(parseLimit({}), 25);
    });

    test('returns parsed value', () {
      expect(parseLimit({'limit': '10'}), 10);
    });

    test('clamps to minimum 1', () {
      expect(parseLimit({'limit': '0'}), 1);
      expect(parseLimit({'limit': '-5'}), 1);
    });

    test('clamps to max 100', () {
      expect(parseLimit({'limit': '999'}), 100);
    });

    test('uses custom default', () {
      expect(parseLimit({}, defaultValue: 50), 50);
    });

    test('uses custom max', () {
      expect(parseLimit({'limit': '200'}, max: 50), 50);
    });

    test('returns default for non-numeric input', () {
      expect(parseLimit({'limit': 'abc'}), 25);
    });
  });

  group('parseOffset', () {
    test('returns default when not provided', () {
      expect(parseOffset({}), 0);
    });

    test('returns parsed value', () {
      expect(parseOffset({'offset': '50'}), 50);
    });

    test('clamps to minimum 0', () {
      expect(parseOffset({'offset': '-10'}), 0);
    });

    test('clamps to max 10000', () {
      expect(parseOffset({'offset': '99999'}), 10000);
    });

    test('returns default for non-numeric input', () {
      expect(parseOffset({'offset': 'xyz'}), 0);
    });
  });
}
