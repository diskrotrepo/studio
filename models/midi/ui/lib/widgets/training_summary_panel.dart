import 'package:flutter/material.dart';

import '../models/training_summary.dart';
import '../theme/app_theme.dart';

/// Displays a complete training summary with model, training config,
/// dataset info, results, and a mini loss chart.
class TrainingSummaryPanel extends StatelessWidget {
  final TrainingSummary summary;

  const TrainingSummaryPanel({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textMuted,
      fontSize: 10,
    );
    final valueStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: 12,
      fontFamily: 'monospace',
    );
    final headerStyle = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textMuted,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    );

    final r = summary.results;
    final m = summary.model;
    final t = summary.training;
    final d = summary.dataset;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Results headline
        Row(
          children: [
            _Stat(
              label: 'Best Loss',
              value: r.bestLoss.toStringAsFixed(4),
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
            const SizedBox(width: 16),
            if (r.bestPerplexity != null)
              _Stat(
                label: 'Perplexity',
                value: r.bestPerplexity!.toStringAsFixed(2),
                labelStyle: labelStyle,
                valueStyle: valueStyle,
              ),
            const SizedBox(width: 16),
            _Stat(
              label: 'Epochs',
              value: r.earlyStopped
                  ? '${r.epochsCompleted}/${r.epochsTotal} (early)'
                  : '${r.epochsCompleted}/${r.epochsTotal}',
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Loss chart
        if (summary.lossHistory.length >= 2) ...[
          SizedBox(
            height: 48,
            child: _MiniLossChart(history: summary.lossHistory),
          ),
          const SizedBox(height: 8),
        ],

        // Model section
        Text('MODEL', style: headerStyle),
        const SizedBox(height: 4),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _Stat(
                label: 'Type',
                value: m.type.replaceAll('MusicTransformer', 'MT'),
                labelStyle: labelStyle,
                valueStyle: valueStyle),
            _Stat(
                label: 'Params',
                value: _formatParams(m.parametersTotal),
                labelStyle: labelStyle,
                valueStyle: valueStyle),
            _Stat(
                label: 'Arch',
                value: 'd${m.dModel} h${m.nHeads} L${m.nLayers}',
                labelStyle: labelStyle,
                valueStyle: valueStyle),
            _Stat(
                label: 'Seq',
                value: '${m.seqLength}',
                labelStyle: labelStyle,
                valueStyle: valueStyle),
            _Stat(
                label: 'Vocab',
                value: '${m.vocabSize}',
                labelStyle: labelStyle,
                valueStyle: valueStyle),
          ],
        ),
        const SizedBox(height: 8),

        // Training section
        Text('TRAINING', style: headerStyle),
        const SizedBox(height: 4),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _Stat(
                label: 'Device',
                value: _shortDevice(t.device),
                labelStyle: labelStyle,
                valueStyle: valueStyle),
            _Stat(
                label: 'Batch',
                value: '${t.effectiveBatchSize}',
                labelStyle: labelStyle,
                valueStyle: valueStyle),
            _Stat(
                label: 'LR',
                value: t.learningRate.toStringAsExponential(1),
                labelStyle: labelStyle,
                valueStyle: valueStyle),
            _Stat(
                label: 'Sched',
                value: t.scheduler,
                labelStyle: labelStyle,
                valueStyle: valueStyle),
            if (t.lora != null)
              _Stat(
                  label: 'LoRA',
                  value: 'r${t.lora!.rank} a${t.lora!.alpha.toInt()}',
                  labelStyle: labelStyle,
                  valueStyle: valueStyle),
          ],
        ),
        const SizedBox(height: 8),

        // Dataset section
        Text('DATASET', style: headerStyle),
        const SizedBox(height: 4),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _Stat(
                label: 'Train',
                value: _formatNumber(d.trainSamples),
                labelStyle: labelStyle,
                valueStyle: valueStyle),
            _Stat(
                label: 'Val',
                value: _formatNumber(d.valSamples),
                labelStyle: labelStyle,
                valueStyle: valueStyle),
            _Stat(
                label: 'Mode',
                value: d.mode,
                labelStyle: labelStyle,
                valueStyle: valueStyle),
          ],
        ),
        const SizedBox(height: 8),

        // Performance section
        Text('PERFORMANCE', style: headerStyle),
        const SizedBox(height: 4),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _Stat(
                label: 'Wall Time',
                value: _formatDuration(r.wallTimeSeconds),
                labelStyle: labelStyle,
                valueStyle: valueStyle),
            _Stat(
                label: 'Avg Epoch',
                value: '${r.avgEpochTimeSeconds.round()}s',
                labelStyle: labelStyle,
                valueStyle: valueStyle),
            _Stat(
                label: 'Throughput',
                value: '${_formatNumber(r.avgThroughputTokS)} tok/s',
                labelStyle: labelStyle,
                valueStyle: valueStyle),
          ],
        ),
      ],
    );
  }

  static String _formatParams(int n) {
    if (n >= 1e9) return '${(n / 1e9).toStringAsFixed(1)}B';
    if (n >= 1e6) return '${(n / 1e6).toStringAsFixed(1)}M';
    if (n >= 1e3) return '${(n / 1e3).toStringAsFixed(0)}K';
    return '$n';
  }

  static String _formatNumber(int n) {
    if (n >= 1e6) return '${(n / 1e6).toStringAsFixed(1)}M';
    if (n >= 1e3) return '${(n / 1e3).toStringAsFixed(n >= 1e4 ? 0 : 1)}k';
    return '$n';
  }

  static String _shortDevice(String device) {
    // Shorten "NVIDIA A100-SXM4-40GB" to "A100 40GB"
    final cleaned = device
        .replaceAll('NVIDIA ', '')
        .replaceAll('-SXM4', '')
        .replaceAll('-PCIe', '')
        .replaceAll('Apple ', '');
    return cleaned.length > 20 ? cleaned.substring(0, 20) : cleaned;
  }

  static String _formatDuration(double seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds.round() % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }
}

/// Tiny stat cell: label above, value below.
class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const _Stat({
    required this.label,
    required this.value,
    this.labelStyle,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 1),
        Text(value, style: valueStyle),
      ],
    );
  }
}

/// Minimal sparkline-style loss chart drawn via CustomPaint.
class _MiniLossChart extends StatelessWidget {
  final List<LossHistoryEntry> history;

  const _MiniLossChart({required this.history});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 48),
      painter: _LossChartPainter(history),
    );
  }
}

class _LossChartPainter extends CustomPainter {
  final List<LossHistoryEntry> history;

  _LossChartPainter(this.history);

  @override
  void paint(Canvas canvas, Size size) {
    if (history.length < 2) return;

    final trainLosses = history.map((e) => e.trainLoss).toList();
    final valLosses = history
        .where((e) => e.valLoss != null)
        .map((e) => e.valLoss!)
        .toList();
    final hasVal = valLosses.isNotEmpty;

    final allLosses = [...trainLosses, ...valLosses];
    final maxLoss = allLosses.reduce((a, b) => a > b ? a : b);
    final minLoss = allLosses.reduce((a, b) => a < b ? a : b);
    final range = maxLoss - minLoss;
    if (range == 0) return;

    double mapY(double loss) {
      return size.height - ((loss - minLoss) / range) * (size.height - 4) - 2;
    }

    double mapX(int index) {
      return (index / (history.length - 1)) * size.width;
    }

    // Train loss line
    final trainPaint = Paint()
      ..color = const Color(0xFF42A5F5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final trainPath = Path();
    for (int i = 0; i < history.length; i++) {
      final x = mapX(i);
      final y = mapY(history[i].trainLoss);
      if (i == 0) {
        trainPath.moveTo(x, y);
      } else {
        trainPath.lineTo(x, y);
      }
    }
    canvas.drawPath(trainPath, trainPaint);

    // Val loss line
    if (hasVal) {
      final valPaint = Paint()
        ..color = const Color(0xFF4caf50)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final valPath = Path();
      bool started = false;
      for (int i = 0; i < history.length; i++) {
        if (history[i].valLoss == null) continue;
        final x = mapX(i);
        final y = mapY(history[i].valLoss!);
        if (!started) {
          valPath.moveTo(x, y);
          started = true;
        } else {
          valPath.lineTo(x, y);
        }
      }
      canvas.drawPath(valPath, valPaint);
    }

    // Legend dots
    final dotRadius = 3.0;
    canvas.drawCircle(
      Offset(size.width - 40, 4),
      dotRadius,
      Paint()..color = const Color(0xFF42A5F5),
    );
    if (hasVal) {
      canvas.drawCircle(
        Offset(size.width - 20, 4),
        dotRadius,
        Paint()..color = const Color(0xFF4caf50),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LossChartPainter old) {
    return old.history != history;
  }
}
