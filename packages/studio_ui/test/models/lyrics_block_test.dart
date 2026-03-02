import 'package:flutter_test/flutter_test.dart';
import 'package:studio_ui/models/lyrics_block.dart';

void main() {
  group('parseLyricsBlocks', () {
    test('parses blocks with headers', () {
      final blocks = parseLyricsBlocks(
        '[verse]\nHello world\n\n[chorus]\nLa la la',
      );
      expect(blocks, hasLength(2));
      expect(blocks[0].header, 'verse');
      expect(blocks[0].content, 'Hello world');
      expect(blocks[1].header, 'chorus');
      expect(blocks[1].content, 'La la la');
    });

    test('returns empty list for empty string', () {
      expect(parseLyricsBlocks(''), isEmpty);
    });

    test('returns empty list for whitespace only', () {
      expect(parseLyricsBlocks('   '), isEmpty);
    });

    test('defaults header to verse for text without header', () {
      final blocks = parseLyricsBlocks('Just some lyrics');
      expect(blocks, hasLength(1));
      expect(blocks[0].header, 'verse');
      expect(blocks[0].content, 'Just some lyrics');
    });

    test('handles multiple lines in a block', () {
      final blocks = parseLyricsBlocks('[verse]\nLine 1\nLine 2\nLine 3');
      expect(blocks, hasLength(1));
      expect(blocks[0].content, contains('Line 1'));
      expect(blocks[0].content, contains('Line 3'));
    });

    test('handles single header with no content', () {
      final blocks = parseLyricsBlocks('[intro]');
      expect(blocks, hasLength(1));
      expect(blocks[0].header, 'intro');
      expect(blocks[0].content, '');
    });
  });

  group('serializeLyricsBlocks', () {
    test('serializes blocks with headers and content', () {
      final blocks = [
        LyricsBlock(header: 'verse', content: 'Hello'),
        LyricsBlock(header: 'chorus', content: 'World'),
      ];
      final result = serializeLyricsBlocks(blocks);
      expect(result, contains('[verse]'));
      expect(result, contains('[chorus]'));
      expect(result, contains('Hello'));
      expect(result, contains('World'));
    });

    test('returns empty string for empty list', () {
      expect(serializeLyricsBlocks([]), '');
    });

    test('round-trips through parse and serialize', () {
      const original = '[verse]\nHello world\n\n[chorus]\nLa la la';
      final blocks = parseLyricsBlocks(original);
      final serialized = serializeLyricsBlocks(blocks);
      final reparsed = parseLyricsBlocks(serialized);
      expect(reparsed, hasLength(blocks.length));
      for (var i = 0; i < blocks.length; i++) {
        expect(reparsed[i].header, blocks[i].header);
        expect(reparsed[i].content, blocks[i].content);
      }
    });
  });
}
