import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:studio_ui/utils/amplitude_extractor.dart';

void main() {
  group('extractAmplitudes', () {
    test('returns zeros for empty bytes', () {
      final result = extractAmplitudes(Uint8List(0), 5);

      expect(result, hasLength(5));
      expect(result, everyElement(0.0));
    });

    test('returns zeros for silence (all 128)', () {
      final bytes = Uint8List.fromList(List.filled(100, 128));
      final result = extractAmplitudes(bytes, 4);

      expect(result, hasLength(4));
      expect(result, everyElement(0.0));
    });

    test('returns normalized values for non-silent audio', () {
      // Create bytes with varying deviation from 128
      final bytes = Uint8List.fromList([
        128, 128, 128, 128, // chunk 0: silence
        200, 200, 200, 200, // chunk 1: loud (deviation 72)
        148, 148, 148, 148, // chunk 2: medium (deviation 20)
        255, 255, 255, 255, // chunk 3: loudest (deviation 127)
      ]);
      final result = extractAmplitudes(bytes, 4);

      expect(result, hasLength(4));
      // chunk 0 is silence => 0.0
      expect(result[0], 0.0);
      // chunk 3 has highest deviation => should be 1.0 (peak)
      expect(result[3], 1.0);
      // others should be between 0 and 1
      expect(result[1], greaterThan(0.0));
      expect(result[1], lessThan(1.0));
      expect(result[2], greaterThan(0.0));
      expect(result[2], lessThan(result[1]));
    });

    test('single count returns single value', () {
      final bytes = Uint8List.fromList([200, 56]);
      final result = extractAmplitudes(bytes, 1);

      expect(result, hasLength(1));
      expect(result[0], 1.0); // peak is normalized to 1.0
    });

    test('handles count larger than byte length', () {
      final bytes = Uint8List.fromList([200, 56]);
      final result = extractAmplitudes(bytes, 10);

      expect(result, hasLength(10));
    });

    test('all values are between 0.0 and 1.0', () {
      final bytes = Uint8List.fromList(
        List.generate(200, (i) => i % 256),
      );
      final result = extractAmplitudes(bytes, 20);

      for (final v in result) {
        expect(v, greaterThanOrEqualTo(0.0));
        expect(v, lessThanOrEqualTo(1.0));
      }
    });
  });
}
