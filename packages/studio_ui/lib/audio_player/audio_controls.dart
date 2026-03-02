import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../application/now_playing.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../utils/error_helpers.dart';
import '../widgets/cover_art.dart';
import 'audio_queue.dart';
import 'bytes_audio_source.dart';

class AudioControls extends StatefulWidget {
  const AudioControls({super.key});

  @override
  State<AudioControls> createState() => _AudioControlsState();
}

class _AudioControlsState extends State<AudioControls> {
  late final AudioPlayer _player;

  bool _loop = false;
  bool _playing = false;
  bool _loading = false;
  String? _error;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double? _dragValueMs;
  bool _isChangingTrack = false;
  String? _currentTrackUrl;

  Timer? _trackEndDebounce;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();

    _player.playerStateStream.listen((ps) {
      if (ps.processingState == ProcessingState.completed) {
        _handleTrackEnded();
      }
    });
    _player.playingStream.listen((playing) {
      if (mounted) setState(() => _playing = playing);
      NowPlaying.instance.playing.value = playing;
    });
    _player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
      _publishProgress();
    });
    _player.durationStream.listen((d) {
      if (mounted) setState(() => _duration = d ?? Duration.zero);
      NowPlaying.instance.durationMs.value = (d ?? Duration.zero).inMilliseconds;
      _publishProgress();
    });

    NowPlaying.instance.track.addListener(_onTrackChanged);

    // Load initial track if one exists.
    if (NowPlaying.instance.track.value != null) {
      _onTrackChanged();
    }
  }

  @override
  void dispose() {
    _trackEndDebounce?.cancel();
    NowPlaying.instance.track.removeListener(_onTrackChanged);
    _player.dispose();
    super.dispose();
  }

  void _handleTrackEnded() {
    if (_isChangingTrack || _loop) return;

    _trackEndDebounce?.cancel();
    _trackEndDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted || _isChangingTrack) return;
      _isChangingTrack = true;
      NowPlaying.instance.next();
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) _isChangingTrack = false;
      });
    });
  }

  void _onTrackChanged() {
    final newTrack = NowPlaying.instance.track.value;
    if (newTrack == null) {
      _player.stop();
      setState(() {
        _currentTrackUrl = null;
        _position = Duration.zero;
        _duration = Duration.zero;
      });
      return;
    }
    if (newTrack.audioUrl == _currentTrackUrl) return;

    _isChangingTrack = true;
    _currentTrackUrl = newTrack.audioUrl;

    final apiClient = context.read<ApiClient>();

    () async {
      await _player.stop();
      setState(() {
        _position = Duration.zero;
        _dragValueMs = null;
        _error = null;
        _loading = true;
      });

      try {
        final bytes = await apiClient.downloadAudioBytes(newTrack.audioUrl);
        if (!mounted) return;
        await _player.setAudioSource(BytesAudioSource(bytes));
        setState(() => _loading = false);
      } catch (e) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = userFriendlyError(e);
          });
        }
        _isChangingTrack = false;
        return;
      }

      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      try {
        await _player.play();
      } catch (_) {}

      Future.delayed(const Duration(milliseconds: 500), () {
        _isChangingTrack = false;
      });
    }();
  }

  void _publishProgress() {
    final dur = _duration.inMilliseconds;
    NowPlaying.instance.progress.value =
        dur > 0 ? (_position.inMilliseconds.clamp(0, dur) / dur) : 0.0;
  }

  Future<void> _handlePlayPause() async {
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> _seekTo(Duration position) async {
    final int total = _duration.inMilliseconds;
    if (total <= 0) return;

    final clampedMs = position.inMilliseconds.clamp(0, total);
    final target = Duration(milliseconds: clampedMs);
    await _player.seek(target);
    setState(() => _dragValueMs = null);
  }

  Future<void> _seekRelative(double rel) async {
    final total = _duration.inMilliseconds;
    if (total <= 0) return;
    final ms = (rel.clamp(0.0, 1.0) * total).round();
    await _seekTo(Duration(milliseconds: ms));
  }

  void _openQueue() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (_) => const QueueSheet(),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final currentTrack = NowPlaying.instance.track.value;
    if (currentTrack == null) return const SizedBox.shrink();

    final int durationMs = _duration.inMilliseconds;
    final int positionMs =
        (_dragValueMs?.round() ?? _position.inMilliseconds);
    final double progress =
        durationMs > 0 ? (positionMs.clamp(0, durationMs) / durationMs) : 0.0;

    final displayPosition = Duration(
      milliseconds:
          (progress * (durationMs > 0 ? durationMs : 0)).round(),
    );

    final filename =
        Uri.tryParse(currentTrack.audioUrl)?.pathSegments.lastOrNull ??
            currentTrack.audioUrl;

    return LayoutBuilder(
      builder: (context, c) {
        final bool compact = c.maxWidth < 560;
        return compact
            ? _buildCompactPlayer(
                context, currentTrack, filename, progress, displayPosition)
            : _buildWidePlayer(
                context, currentTrack, filename, progress, displayPosition);
      },
    );
  }

  Widget _buildCompactPlayer(
    BuildContext context,
    PlayingTrack track,
    String filename,
    double progress,
    Duration displayPosition,
  ) {
    final s = S.of(context);
    final int durationMs = _duration.inMilliseconds;

    return Row(
      children: [
        CoverArt(audioUrl: track.audioUrl, size: 44, playbackProgress: progress, isPlaying: _playing),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_error != null)
                Text(
                  _error!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                )
              else
                Text(
                  filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    _formatDuration(displayPosition),
                    style: const TextStyle(
                        color: AppColors.text, fontSize: 10),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _ScrubberBar(
                      progress: progress,
                      enabled: durationMs > 0,
                      trackColor: AppColors.textMuted.withValues(alpha: .3),
                      scrubberColor: AppColors.controlPink,
                      onUpdateRelative: (rel) => setState(
                        () =>
                            _dragValueMs = (rel.clamp(0.0, 1.0) * durationMs),
                      ),
                      onSeekRelative: _seekRelative,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatDuration(_duration),
                    style: const TextStyle(
                        color: AppColors.text, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              iconSize: 22,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.skip_previous, color: AppColors.text),
              onPressed: () => NowPlaying.instance.previous(),
              tooltip: s.tooltipPrevious,
            ),
            IconButton(
              iconSize: 26,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                _playing ? Icons.pause : Icons.play_arrow,
                color: AppColors.text,
              ),
              onPressed: _loading ? null : _handlePlayPause,
              tooltip: _playing ? s.tooltipPause : s.tooltipPlay,
            ),
            IconButton(
              iconSize: 22,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.skip_next, color: AppColors.text),
              onPressed: () => NowPlaying.instance.next(),
              tooltip: s.tooltipNext,
            ),
            IconButton(
              iconSize: 22,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.queue_music, color: AppColors.text),
              onPressed: _openQueue,
              tooltip: s.tooltipQueue,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWidePlayer(
    BuildContext context,
    PlayingTrack track,
    String filename,
    double progress,
    Duration displayPosition,
  ) {
    final s = S.of(context);
    final int durationMs = _duration.inMilliseconds;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CoverArt(audioUrl: track.audioUrl, size: 50, playbackProgress: progress, isPlaying: _playing),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (_error != null)
                        Text(
                          _error!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                          ),
                        )
                      else
                        Text(
                          filename,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: LayoutBuilder(
              builder: (_, constraints) {
                final double cap =
                    math.min(720, constraints.maxWidth * 0.6);
                final double maxWidth = math.max(360, cap);
                return ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.skip_previous,
                                color: AppColors.text),
                            tooltip: s.tooltipPrevious,
                            onPressed: () =>
                                NowPlaying.instance.previous(),
                          ),
                          IconButton(
                            icon: Icon(
                              _playing
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: AppColors.text,
                            ),
                            tooltip: _playing ? s.tooltipPause : s.tooltipPlay,
                            onPressed:
                                _loading ? null : _handlePlayPause,
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_next,
                                color: AppColors.text),
                            tooltip: s.tooltipNext,
                            onPressed: () =>
                                NowPlaying.instance.next(),
                          ),
                          IconButton(
                            icon: Icon(
                              _loop
                                  ? Icons.repeat_one
                                  : Icons.repeat,
                              color: AppColors.text,
                            ),
                            tooltip: s.tooltipLoop,
                            onPressed: () async {
                              _loop = !_loop;
                              await _player.setLoopMode(
                                _loop
                                    ? LoopMode.one
                                    : LoopMode.off,
                              );
                              setState(() {});
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.queue_music,
                                color: AppColors.text),
                            tooltip: s.tooltipShowQueue,
                            onPressed: _openQueue,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            _formatDuration(displayPosition),
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ScrubberBar(
                              progress: progress,
                              enabled: durationMs > 0,
                              trackColor: AppColors.textMuted
                                  .withValues(alpha: .3),
                              scrubberColor: AppColors.controlPink,
                              onUpdateRelative: (rel) => setState(
                                () => _dragValueMs =
                                    (rel.clamp(0.0, 1.0) *
                                        durationMs),
                              ),
                              onSeekRelative: _seekRelative,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDuration(_duration),
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ScrubberBar extends StatelessWidget {
  const _ScrubberBar({
    required this.progress,
    required this.enabled,
    required this.trackColor,
    required this.scrubberColor,
    required this.onUpdateRelative,
    required this.onSeekRelative,
  });

  final double progress;
  final bool enabled;
  final Color trackColor;
  final Color scrubberColor;
  final ValueChanged<double> onUpdateRelative;
  final ValueChanged<double> onSeekRelative;

  @override
  Widget build(BuildContext context) {
    const double height = 24;
    const double trackHeight = 4;
    const double scrubberWidth = 16;
    const double scrubberHeight = 16;

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double w = constraints.maxWidth;
          final double x = (progress.clamp(0.0, 1.0) * w).clamp(0.0, w);

          void updateFromDx(double dx) {
            if (!enabled || w <= 0) return;
            final rel = (dx / w).clamp(0.0, 1.0);
            onUpdateRelative(rel);
          }

          Future<void> commitFromDx(double dx) async {
            if (!enabled || w <= 0) return;
            final rel = (dx / w).clamp(0.0, 1.0);
            onSeekRelative(rel);
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) async {
              if (!enabled) return;
              await commitFromDx(d.localPosition.dx);
            },
            onHorizontalDragStart: (d) {
              if (!enabled) return;
              updateFromDx(d.localPosition.dx);
            },
            onHorizontalDragUpdate: (d) {
              if (!enabled) return;
              updateFromDx(d.localPosition.dx);
            },
            onHorizontalDragEnd: (_) {
              if (!enabled || w <= 0) return;
              onSeekRelative((x / w).clamp(0.0, 1.0));
            },
            onHorizontalDragCancel: () {
              if (!enabled || w <= 0) return;
              onSeekRelative((x / w).clamp(0.0, 1.0));
            },
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Positioned.fill(
                  child: Center(
                    child:
                        Container(height: trackHeight, color: trackColor),
                  ),
                ),
                Positioned(
                  left: (x - scrubberWidth / 2)
                      .clamp(0.0, w - scrubberWidth),
                  top: (height - scrubberHeight) / 2,
                  child: Container(
                    width: scrubberWidth,
                    height: scrubberHeight,
                    color: scrubberColor,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
