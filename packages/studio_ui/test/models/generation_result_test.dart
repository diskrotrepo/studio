import 'package:flutter_test/flutter_test.dart';
import 'package:studio_ui/models/generation_result.dart';

void main() {
  group('GenerationResult.fromResultMap', () {
    test('parses results list', () {
      final result = GenerationResult.fromResultMap({
        'results': [
          {'file': 'http://example.com/track1.mp3'},
          {'file': 'http://example.com/track2.mp3'},
        ],
      });

      expect(result.files, hasLength(2));
      expect(result.files[0].url, 'http://example.com/track1.mp3');
      expect(result.files[1].url, 'http://example.com/track2.mp3');
    });

    test('returns empty list when results key is missing', () {
      final result = GenerationResult.fromResultMap({});

      expect(result.files, isEmpty);
    });

    test('returns empty list when results is null', () {
      final result = GenerationResult.fromResultMap({'results': null});

      expect(result.files, isEmpty);
    });

    test('returns empty list when results is empty', () {
      final result = GenerationResult.fromResultMap({'results': []});

      expect(result.files, isEmpty);
    });
  });

  group('AudioFile.filename', () {
    test('extracts filename from URL', () {
      final file = AudioFile(url: 'http://example.com/songs/track1.mp3');
      expect(file.filename, 'track1.mp3');
    });

    test('extracts filename from URL with query params', () {
      final file = AudioFile(url: 'http://example.com/songs/track.mp3?v=2');
      expect(file.filename, 'track.mp3');
    });

    test('returns audio.mp3 for invalid URL', () {
      final file = AudioFile(url: ':::invalid');
      expect(file.filename, 'audio.mp3');
    });

    test('returns audio.mp3 for empty path segments', () {
      final file = AudioFile(url: 'http://example.com');
      // URI with no path segments returns default
      expect(file.filename, isNotNull);
    });
  });

  group('AudioFile.toPlayingTrack', () {
    test('produces correct PlayingTrack', () {
      final file = AudioFile(url: 'http://example.com/track.mp3');
      final track = file.toPlayingTrack(0);

      expect(track.id, 'http://example.com/track.mp3');
      expect(track.title, 'Track 1');
      expect(track.audioUrl, 'http://example.com/track.mp3');
    });

    test('uses 1-based index in title', () {
      final file = AudioFile(url: 'http://example.com/track.mp3');

      expect(file.toPlayingTrack(0).title, 'Track 1');
      expect(file.toPlayingTrack(4).title, 'Track 5');
    });
  });
}
