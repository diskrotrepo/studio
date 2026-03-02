import 'dart:collection';

import 'package:flutter/foundation.dart';

class NowPlaying {
  NowPlaying._();
  static final instance = NowPlaying._();

  /// Current track (null => no player visible)
  final ValueNotifier<PlayingTrack?> track = ValueNotifier<PlayingTrack?>(null);

  /// Whether audio is actively playing (not paused/stopped).
  final ValueNotifier<bool> playing = ValueNotifier<bool>(false);

  /// Current playback progress (0.0–1.0).
  final ValueNotifier<double> progress = ValueNotifier<double>(0);

  /// Current track duration in milliseconds (0 when unknown).
  final ValueNotifier<int> durationMs = ValueNotifier<int>(0);

  /// Full queue and the current index in that queue.
  final ValueNotifier<List<PlayingTrack>> queue =
      ValueNotifier<List<PlayingTrack>>(<PlayingTrack>[]);
  final ValueNotifier<int> index = ValueNotifier<int>(-1);

  /// Convenience unmodifiable view (e.g. for UI lists).
  UnmodifiableListView<PlayingTrack> get queueView =>
      UnmodifiableListView(queue.value);

  bool get hasTrack => track.value != null;
  bool get hasNext => index.value >= 0 && index.value < queue.value.length - 1;
  bool get hasPrevious => index.value > 0;

  /// Play a single track immediately (replaces queue).
  void play(PlayingTrack t) {
    setQueue([t], startAt: 0, autoplay: true);
  }

  /// Stop playback and clear current item (queue remains by default).
  void stop({bool clearQueue = false}) {
    track.value = null;
    index.value = -1;
    if (clearQueue) queue.value = <PlayingTrack>[];
  }

  /// Replace the queue and optionally start at a given index.
  void setQueue(
    List<PlayingTrack> tracks, {
    int startAt = 0,
    bool autoplay = true,
  }) {
    stop(clearQueue: true);

    final list = List<PlayingTrack>.from(tracks);
    queue.value = list;

    if (list.isEmpty) {
      index.value = -1;
      track.value = null;
      return;
    }

    final clamped = startAt.clamp(0, list.length - 1);
    index.value = clamped;
    if (autoplay) {
      track.value = list[clamped];
    } else {
      track.value = null;
    }
  }

  /// Replace the queue but start paused.
  void prepareQueue(List<PlayingTrack> tracks, {int startAt = 0}) {
    setQueue(tracks, startAt: startAt, autoplay: false);
  }

  /// Jump to an item already in the queue.
  void playIndex(int i) {
    if (i < 0 || i >= queue.value.length) return;
    index.value = i;
    track.value = queue.value[i];
  }

  /// Find a track by id in the queue and jump to it.
  void playById(String id) {
    final i = queue.value.indexWhere((t) => t.id == id);
    if (i != -1) playIndex(i);
  }

  /// Add to end of queue.
  void enqueue(PlayingTrack t) {
    final list = List<PlayingTrack>.from(queue.value)..add(t);
    queue.value = list;
  }

  /// Add many to end of queue.
  void enqueueAll(List<PlayingTrack> tracks) {
    if (tracks.isEmpty) return;
    final list = List<PlayingTrack>.from(queue.value)..addAll(tracks);
    queue.value = list;
  }

  /// Insert directly after the current track (or at start if none).
  void enqueueNext(PlayingTrack t) {
    final list = List<PlayingTrack>.from(queue.value);
    final insertAt = index.value >= 0 ? index.value + 1 : 0;
    list.insert(insertAt, t);
    queue.value = list;
  }

  /// Replace current track with t and continue.
  void playNow(PlayingTrack t) {
    if (index.value < 0) {
      setQueue([t], startAt: 0, autoplay: true);
      return;
    }
    final list = List<PlayingTrack>.from(queue.value);
    list[index.value] = t;
    queue.value = list;
    track.value = t;
  }

  /// Remove an item. If it was before the current index, shift index back.
  void removeAt(int i) {
    if (i < 0 || i >= queue.value.length) return;
    final list = List<PlayingTrack>.from(queue.value)..removeAt(i);

    if (list.isEmpty) {
      queue.value = list;
      stop(clearQueue: true);
      return;
    }

    if (i < index.value) {
      index.value = index.value - 1;
    } else if (i == index.value) {
      final newIndex = index.value >= list.length
          ? list.length - 1
          : index.value;
      index.value = newIndex;
      track.value = list[newIndex];
    }

    queue.value = list;
  }

  /// Clear entire queue (and stop).
  void clearQueue() {
    queue.value = <PlayingTrack>[];
    stop(clearQueue: true);
  }

  /// Next / previous navigation.
  void next() {
    if (!hasNext) return;
    final i = index.value + 1;
    index.value = i;
    track.value = queue.value[i];
  }

  void previous() {
    if (!hasPrevious) return;
    final i = index.value - 1;
    index.value = i;
    track.value = queue.value[i];
  }
}

class PlayingTrack {
  const PlayingTrack({
    required this.id,
    required this.title,
    required this.audioUrl,
  });

  final String id;
  final String title;
  final String audioUrl;
}
