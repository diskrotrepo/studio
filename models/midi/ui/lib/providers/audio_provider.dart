import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../services/audio_service.dart';

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Task ID of the currently playing track.
final currentlyPlayingTaskProvider = StateProvider<String?>((ref) => null);

/// Stream of player state changes.
final playerStateProvider = StreamProvider<PlayerState>((ref) {
  return ref.watch(audioServiceProvider).playerStateStream;
});

/// Stream of playback position.
final playerPositionProvider = StreamProvider<Duration>((ref) {
  return ref.watch(audioServiceProvider).positionStream;
});

/// Stream of total duration.
final playerDurationProvider = StreamProvider<Duration?>((ref) {
  return ref.watch(audioServiceProvider).durationStream;
});
