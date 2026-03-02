import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/amplitude_extractor.dart';
import 'visualizers/shader_cache.dart';
import 'visualizers/shader_visualizer_painter.dart';
import 'visualizers/visualizer_type.dart';

/// Number of amplitude bars used for cover art generation.
const _kBarCount = 4096;

class _CoverArtData {
  _CoverArtData(this.amplitudes, this.colorSeed);
  final List<double> amplitudes;
  final int colorSeed;
}

/// Global cache so every [CoverArt] widget sharing the same URL reuses data.
final Map<String, _CoverArtData> _cache = {};

/// Compute a simple hash from audio bytes to seed the colour palette.
int _hashBytes(Uint8List bytes) {
  int hash = 0x811c9dc5; // FNV offset basis
  final step = (bytes.length / 512).ceil().clamp(1, bytes.length);
  for (int i = 0; i < bytes.length; i += step) {
    hash ^= bytes[i];
    hash = (hash * 0x01000193) & 0x7FFFFFFF; // FNV prime, keep positive
  }
  return hash;
}

// ── Frequency band extraction ──

/// Computes bass / mid / treble using multi-scale windowing around the current
/// playback position.  A wide window (±50 bins) yields a slow-moving bass
/// signal, a medium window (±15) gives mid, and a narrow window (±3) gives a
/// fast-reacting treble.  When [progress] is null the overall average is
/// returned for all three bands.
({double bass, double mid, double treble}) _frequencyBandsAt(
    List<double> amps, double? progress) {
  if (amps.isEmpty) return (bass: 0, mid: 0, treble: 0);

  if (progress == null) {
    double sum = 0;
    for (final a in amps) {
      sum += a;
    }
    final avg = sum / amps.length;
    return (bass: avg, mid: avg, treble: avg);
  }

  final count = amps.length;
  final center = (progress * count).floor().clamp(0, count - 1);

  double windowAvg(int halfWin) {
    double sum = 0;
    int n = 0;
    for (int i = center - halfWin; i <= center + halfWin; i++) {
      if (i >= 0 && i < count) {
        sum += amps[i];
        n++;
      }
    }
    return n > 0 ? sum / n : 0;
  }

  return (
    bass: windowAvg(400),
    mid: windowAvg(80),
    treble: windowAvg(8),
  );
}

/// Beat intensity from playback position (matches the algorithm used by the
/// old Canvas painters).
double _computeBeat(List<double> amps, double? progress, double? phase) {
  if (amps.isEmpty) return 0;
  final count = amps.length;
  double avgAmp = 0;
  for (final a in amps) {
    avgAmp += a;
  }
  avgAmp /= count;

  final double rawBeat;
  if (progress != null && phase != null) {
    final center = (progress * count).floor().clamp(0, count - 1);
    final halfWin = (count * 0.015).round().clamp(3, 24);
    double sum = 0;
    int n = 0;
    for (int j = center - halfWin; j <= center + halfWin; j++) {
      if (j >= 0 && j < count) {
        sum += amps[j];
        n++;
      }
    }
    rawBeat = (n > 0 ? sum / n : avgAmp).clamp(0.0, 1.0);
  } else {
    rawBeat = avgAmp;
  }
  return rawBeat * rawBeat;
}

/// Displays a procedurally generated cover art image derived from the audio
/// waveform at [audioUrl].
///
/// Shows a placeholder while loading. The generated data is cached globally so
/// multiple widgets with the same URL share a single download.
///
/// When [isPlaying] is true, the GPU shader animates with a 2-second cycle.
class CoverArt extends StatefulWidget {
  const CoverArt({
    super.key,
    required this.audioUrl,
    required this.size,
    this.borderRadius = 2.0,
    this.playbackProgress,
    this.isPlaying = false,
    this.selected = false,
  });

  final String audioUrl;
  final double size;
  final double borderRadius;

  /// When non-null (0.0–1.0), played region is bright and unplayed region dim.
  final double? playbackProgress;

  /// When true, the shader animates.
  final bool isPlaying;

  /// When true, the shader renders brighter.
  final bool selected;

  @override
  State<CoverArt> createState() => _CoverArtState();
}

class _CoverArtState extends State<CoverArt>
    with SingleTickerProviderStateMixin {
  _CoverArtData? _data;
  bool _loading = false;
  late final AnimationController _pulse;

  // Smooth progress interpolation state.
  double _lastProgress = 0;
  DateTime _lastProgressTime = DateTime.now();
  double _progressRate = 0; // progress units per second

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.isPlaying) _pulse.repeat();
    _lastProgress = widget.playbackProgress ?? 0;
    _loadData();
    ShaderCache.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant CoverArt old) {
    super.didUpdateWidget(old);
    if (old.audioUrl != widget.audioUrl) {
      _data = _cache[widget.audioUrl];
      if (_data == null) _loadData();
      _progressRate = 0;
    }
    // Update interpolation state when progress changes.
    final newP = widget.playbackProgress;
    if (newP != null && newP != old.playbackProgress) {
      final now = DateTime.now();
      final dt = now.difference(_lastProgressTime).inMicroseconds / 1e6;
      if (dt > 0.01 && _lastProgress < newP) {
        _progressRate = (newP - _lastProgress) / dt;
      }
      _lastProgress = newP;
      _lastProgressTime = now;
    }
    if (widget.isPlaying && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!widget.isPlaying && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  /// Returns smoothly interpolated progress at ~60fps.
  double? get _smoothProgress {
    final base = widget.playbackProgress;
    if (base == null) return null;
    if (!widget.isPlaying || _progressRate <= 0) return base;
    final elapsed =
        DateTime.now().difference(_lastProgressTime).inMicroseconds / 1e6;
    return (_lastProgress + elapsed * _progressRate).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final cached = _cache[widget.audioUrl];
    if (cached != null) {
      setState(() => _data = cached);
      return;
    }

    setState(() => _loading = true);

    try {
      final api = context.read<ApiClient>();
      final bytes = await api.downloadAudioBytes(widget.audioUrl);
      if (!mounted) return;
      final amps = extractAmplitudes(bytes, _kBarCount);
      final seed = _hashBytes(bytes);
      final data = _CoverArtData(amps, seed);
      _cache[widget.audioUrl] = data;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;

    final radius = BorderRadius.circular(widget.borderRadius);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: const Color(0x30FFFFFF),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: data != null && ShaderCache.isLoaded
            ? ValueListenableBuilder<VisualizerType>(
                valueListenable:
                    context.read<ApiClient>().visualizerType,
                builder: (context, vizType, _) {
                  final program = ShaderCache.forType(vizType);
                  if (program == null) {
                    return Container(color: const Color(0xFF08080E));
                  }
                  return AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) {
                      final progress = _smoothProgress;
                      final bands = _frequencyBandsAt(
                        data.amplitudes, progress);
                      final beat = _computeBeat(
                        data.amplitudes,
                        progress,
                        widget.isPlaying ? _pulse.value : null,
                      );
                      final scale = widget.isPlaying
                          ? 1.0 + beat * 0.06
                          : 1.0;
                      return Transform.scale(
                        scale: scale,
                        child: CustomPaint(
                          size: Size.square(widget.size),
                          painter: ShaderVisualizerPainter(
                            shader: program.fragmentShader(),
                            time: widget.isPlaying ? _pulse.value : 0.0,
                            bass: bands.bass,
                            mid: bands.mid,
                            treble: bands.treble,
                            beat: beat,
                            colorSeed: (data.colorSeed % 360).toDouble(),
                            selected: widget.selected,
                            playbackProgress: progress,
                          ),
                        ),
                      );
                    },
                  );
                },
              )
            : Container(
                color: AppColors.surfaceHigh,
                child: _loading
                    ? const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.controlPink,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.music_note,
                        color: AppColors.controlPink,
                        size: 20,
                      ),
              ),
        ),
      ),
    );
  }
}
