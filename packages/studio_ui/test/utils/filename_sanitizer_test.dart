import 'package:flutter_test/flutter_test.dart';
import 'package:studio_ui/utils/filename_sanitizer.dart';

void main() {
  group('sanitizeFilename', () {
    test('preserves normal filenames', () {
      expect(sanitizeFilename('my_dataset.zip'), 'my_dataset.zip');
    });

    test('preserves spaces and hyphens', () {
      expect(sanitizeFilename('my dataset-v2.zip'), 'my dataset-v2.zip');
    });

    test('strips directory components with forward slashes', () {
      expect(sanitizeFilename('/path/to/file.zip'), 'file.zip');
    });

    test('strips directory components with backslashes', () {
      expect(sanitizeFilename('C:\\Users\\file.zip'), 'file.zip');
    });

    test('removes path traversal sequences', () {
      expect(sanitizeFilename('../../etc/passwd'), 'passwd');
    });

    test('removes unsafe characters', () {
      expect(sanitizeFilename('file<name>.zip'), 'filename.zip');
    });

    test('returns upload for empty result', () {
      expect(sanitizeFilename('///'), 'upload');
    });

    test('returns upload for only unsafe chars', () {
      expect(sanitizeFilename('<>|'), 'upload');
    });

    test('collapses multiple dots', () {
      expect(sanitizeFilename('file...zip'), 'file.zip');
    });

    test('handles mixed path separators', () {
      expect(sanitizeFilename('/home\\user/file.zip'), 'file.zip');
    });

    test('handles empty string', () {
      expect(sanitizeFilename(''), 'upload');
    });
  });
}
