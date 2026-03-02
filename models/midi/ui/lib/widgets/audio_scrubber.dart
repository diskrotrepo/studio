import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/audio_provider.dart';
import '../theme/app_theme.dart';

class AudioScrubber extends ConsumerStatefulWidget {
  /// If true, render in compact mode (thin bar, no time labels).
  final bool compact;

  const AudioScrubber({super.key, this.compact = false});

  @override
  ConsumerState<AudioScrubber> createState() => _AudioScrubberState();
}

class _AudioScrubberState extends ConsumerState<AudioScrubber> {
  bool _isDragging = false;
  double _dragValue = 0.0;
  double? _seekTarget;

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(playerPositionProvider);
    final duration = ref.watch(playerDurationProvider);

    final pos = position.valueOrNull ?? Duration.zero;
    final dur = duration.valueOrNull ?? Duration.zero;

    final progress = dur.inMilliseconds > 0
        ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    // Clear seek target once position stream catches up.
    if (_seekTarget != null && (progress - _seekTarget!).abs() < 0.03) {
      _seekTarget = null;
    }

    final sliderValue = _isDragging
        ? _dragValue
        : (_seekTarget ?? progress).clamp(0.0, 1.0);
    final displayPos = _isDragging
        ? Duration(milliseconds: (_dragValue * dur.inMilliseconds).round())
        : _seekTarget != null
            ? Duration(
                milliseconds: (_seekTarget! * dur.inMilliseconds).round())
            : pos;

    final slider = SliderTheme(
      data: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: AppColors.controlBlue,
        inactiveTrackColor: AppColors.border,
        thumbColor: AppColors.controlBlue,
        overlayColor: AppColors.controlBlue.withValues(alpha: 0.2),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        trackShape: const RectangularSliderTrackShape(),
      ),
      child: Slider(
        value: sliderValue,
        onChangeStart: (value) {
          setState(() {
            _isDragging = true;
            _dragValue = value;
          });
        },
        onChanged: (value) {
          setState(() {
            _dragValue = value;
          });
        },
        onChangeEnd: (value) async {
          setState(() {
            _isDragging = false;
            _seekTarget = value;
          });
          if (dur.inMilliseconds > 0) {
            final seekPos = Duration(
              milliseconds: (value * dur.inMilliseconds).round(),
            );
            await ref.read(audioServiceProvider).seek(seekPos);
          }
        },
      ),
    );

    if (widget.compact) {
      return SizedBox(
        height: 24,
        child: slider,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Text(
            _formatDuration(displayPos),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
          ),
          Expanded(child: slider),
          Text(
            _formatDuration(dur),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
