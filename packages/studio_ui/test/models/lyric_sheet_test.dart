import 'package:flutter_test/flutter_test.dart';
import 'package:studio_ui/models/lyric_sheet.dart';

void main() {
  group('LyricSheet.fromJson', () {
    test('parses all fields', () {
      final ls = LyricSheet.fromJson({
        'id': 'ls-1',
        'title': 'My Song',
        'content': 'Hello world',
        'created_at': '2024-06-01T12:00:00Z',
      });
      expect(ls.id, 'ls-1');
      expect(ls.title, 'My Song');
      expect(ls.content, 'Hello world');
      expect(ls.createdAt, isNotNull);
    });

    test('defaults title to empty string', () {
      final ls = LyricSheet.fromJson({
        'id': 'ls-2',
        'title': null,
        'content': 'test',
      });
      expect(ls.title, '');
    });

    test('defaults content to empty string', () {
      final ls = LyricSheet.fromJson({
        'id': 'ls-3',
        'title': 'Test',
        'content': null,
      });
      expect(ls.content, '');
    });

    test('handles null created_at', () {
      final ls = LyricSheet.fromJson({
        'id': 'ls-4',
        'title': 'Test',
        'content': '',
      });
      expect(ls.createdAt, isNull);
    });
  });

  group('LyricSheet.copyWith', () {
    test('copies with new title', () {
      final ls = LyricSheet(id: 'ls-1', title: 'Old', content: 'text');
      final copy = ls.copyWith(title: 'New');
      expect(copy.title, 'New');
      expect(copy.content, 'text');
      expect(copy.id, 'ls-1');
    });

    test('copies with new content', () {
      final ls = LyricSheet(id: 'ls-1', title: 'Title', content: 'old');
      final copy = ls.copyWith(content: 'new lyrics');
      expect(copy.content, 'new lyrics');
      expect(copy.title, 'Title');
    });

    test('preserves fields when no arguments given', () {
      final ls = LyricSheet(id: 'ls-1', title: 'Keep', content: 'This');
      final copy = ls.copyWith();
      expect(copy.title, 'Keep');
      expect(copy.content, 'This');
    });
  });
}
