import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ParameterControls extends StatelessWidget {
  final int duration;
  final int bpm;
  final double temperature;
  final ValueChanged<int> onDurationChanged;
  final ValueChanged<int> onBpmChanged;
  final ValueChanged<double> onTemperatureChanged;

  const ParameterControls({
    super.key,
    required this.duration,
    required this.bpm,
    required this.temperature,
    required this.onDurationChanged,
    required this.onBpmChanged,
    required this.onTemperatureChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      color: AppColors.textMuted,
    );

    return Column(
      children: [
        _SliderRow(
          label: 'Duration',
          tooltip: 'duration — length of generated MIDI in seconds',
          value: '${duration.clamp(5, 30)}s',
          slider: Slider(
            value: duration.clamp(5, 30).toDouble(),
            min: 5,
            max: 30,
            divisions: 25,
            activeColor: AppColors.controlBlue,
            onChanged: (v) => onDurationChanged(v.round()),
          ),
          labelStyle: labelStyle,
        ),
        _SliderRow(
          label: 'BPM',
          tooltip: 'bpm — beats per minute, controls the tempo',
          value: '$bpm',
          slider: Slider(
            value: bpm.toDouble(),
            min: 40,
            max: 250,
            divisions: 42,
            activeColor: AppColors.controlBlue,
            onChanged: (v) => onBpmChanged(v.round()),
          ),
          labelStyle: labelStyle,
        ),
        _SliderRow(
          label: 'Boldness',
          tooltip: 'temperature — higher values produce more unexpected results',
          value: temperature.toStringAsFixed(1),
          slider: Slider(
            value: temperature,
            min: 0.1,
            max: 2.0,
            divisions: 19,
            activeColor: AppColors.controlBlue,
            onChanged: onTemperatureChanged,
          ),
          labelStyle: labelStyle,
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final String value;
  final Widget slider;
  final TextStyle? labelStyle;
  final String? tooltip;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.slider,
    this.labelStyle,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: labelStyle),
                if (tooltip != null) ...[
                  const SizedBox(width: 4),
                  Tooltip(
                    message: tooltip!,
                    child: Icon(
                      Icons.info_outline,
                      size: 14,
                      color: AppColors.textMuted.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: SquareThumbShape(),
                thumbColor: AppColors.controlBlue,
                activeTrackColor: AppColors.controlBlue,
                overlayColor: AppColors.controlBlue.withValues(alpha: 0.2),
                inactiveTrackColor: AppColors.border,
                tickMarkShape: SliderTickMarkShape.noTickMark,
              ),
              child: slider,
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              value,
              style: labelStyle,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}


class SquareThumbShape extends SliderComponentShape {
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(14, 14);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final rect = Rect.fromCenter(center: center, width: 14, height: 14);
    final paint = Paint()..color = sliderTheme.thumbColor ?? AppColors.controlBlue;
    canvas.drawRect(rect, paint);
  }
}

class AdvancedControls extends StatelessWidget {
  final int topK;
  final double topP;
  final double repetitionPenalty;
  final String? humanize;
  final int? seed;
  final ValueChanged<int> onTopKChanged;
  final ValueChanged<double> onTopPChanged;
  final ValueChanged<double> onRepetitionPenaltyChanged;
  final ValueChanged<String?> onHumanizeChanged;
  final ValueChanged<int?> onSeedChanged;

  const AdvancedControls({
    super.key,
    required this.topK,
    required this.topP,
    required this.repetitionPenalty,
    required this.humanize,
    required this.seed,
    required this.onTopKChanged,
    required this.onTopPChanged,
    required this.onRepetitionPenaltyChanged,
    required this.onHumanizeChanged,
    required this.onSeedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      color: AppColors.textMuted,
    );

    return Column(
      children: [
        _SliderRow(
          label: 'Variety',
          tooltip: 'top_k — limits sampling to the top K most likely tokens',
          value: '$topK',
          slider: Slider(
            value: topK.toDouble(),
            min: 0,
            max: 500,
            divisions: 50,
            activeColor: AppColors.controlBlue,
            onChanged: (v) => onTopKChanged(v.round()),
          ),
          labelStyle: labelStyle,
        ),
        _SliderRow(
          label: 'Creativity',
          tooltip: 'top_p — nucleus sampling, keeps tokens within cumulative probability P',
          value: topP.toStringAsFixed(2),
          slider: Slider(
            value: topP,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            activeColor: AppColors.controlBlue,
            onChanged: onTopPChanged,
          ),
          labelStyle: labelStyle,
        ),
        _SliderRow(
          label: 'Rep. Penalty',
          tooltip: 'repetition_penalty — penalizes repeated token sequences',
          value: repetitionPenalty.toStringAsFixed(1),
          slider: Slider(
            value: repetitionPenalty,
            min: 1.0,
            max: 3.0,
            divisions: 20,
            activeColor: AppColors.controlBlue,
            onChanged: onRepetitionPenaltyChanged,
          ),
          labelStyle: labelStyle,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 100,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Humanize', style: labelStyle),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'humanize — adds subtle timing variations for a natural feel',
                    child: Icon(
                      Icons.info_outline,
                      size: 14,
                      color: AppColors.textMuted.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SegmentedButton<String?>(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppColors.controlBlue;
                    }
                    return null;
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.white;
                    }
                    return null;
                  }),
                ),
                segments: const [
                  ButtonSegment(value: null, label: Text('Off')),
                  ButtonSegment(value: 'light', label: Text('Light')),
                  ButtonSegment(value: 'medium', label: Text('Medium')),
                  ButtonSegment(value: 'heavy', label: Text('Heavy')),
                ],
                selected: {humanize},
                onSelectionChanged: (s) => onHumanizeChanged(s.first),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            SizedBox(
              width: 100,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Seed', style: labelStyle),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'seed — fixed number for reproducible results',
                    child: Icon(
                      Icons.info_outline,
                      size: 14,
                      color: AppColors.textMuted.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Random (leave empty)',
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                controller: TextEditingController(
                  text: seed?.toString() ?? '',
                ),
                onChanged: (v) {
                  final parsed = int.tryParse(v);
                  onSeedChanged(parsed);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
