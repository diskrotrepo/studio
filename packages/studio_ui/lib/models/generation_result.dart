import '../application/now_playing.dart';

class GenerationResult {
  GenerationResult({required this.files});

  factory GenerationResult.fromResultMap(Map<String, dynamic> result) {
    final rawResults = result['results'] as List<dynamic>? ?? [];
    final files = rawResults
        .cast<Map<String, dynamic>>()
        .map((r) => AudioFile(url: r['file'] as String))
        .toList();
    return GenerationResult(files: files);
  }

  final List<AudioFile> files;
}

class AudioFile {
  AudioFile({required this.url});
  final String url;

  String get filename {
    final uri = Uri.tryParse(url);
    if (uri == null) return 'audio.mp3';
    final segments = uri.pathSegments;
    return segments.isNotEmpty ? segments.last : 'audio.mp3';
  }

  PlayingTrack toPlayingTrack(int index) => PlayingTrack(
        id: url,
        title: 'Track ${index + 1}',
        audioUrl: url,
      );
}
