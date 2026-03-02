import 'package:flutter/material.dart';

import '../models/training_metrics.dart';
import '../theme/app_theme.dart';

class TrainingMetricsPanel extends StatelessWidget {
  final TrainingMetrics metrics;

  const TrainingMetricsPanel({super.key, required this.metrics});

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Epoch row with progress
        Row(
          children: [
            Text(
              'Epoch ${metrics.epoch}/${metrics.totalEpochs}',
              style: valueStyle,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: metrics.epochProgress,
                  minHeight: 4,
                  backgroundColor: AppColors.border,
                  valueColor:
                      const AlwaysStoppedAnimation(Color(0xFF42A5F5)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(metrics.epochProgress * 100).round()}%',
              style: labelStyle,
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Loss row
        Row(
          children: [
            _MetricCell(
              label: 'Train Loss',
              value: metrics.trainLoss.toStringAsFixed(4),
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
            if (metrics.valLoss != null) ...[
              const SizedBox(width: 16),
              _MetricCell(
                label: 'Val Loss',
                value: metrics.valLoss!.toStringAsFixed(4),
                labelStyle: labelStyle,
                valueStyle: valueStyle,
                suffix: _lossDeltaSuffix(),
                suffixColor: _lossDeltaColor(),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),

        // LR + throughput
        Row(
          children: [
            if (metrics.lr != null)
              _MetricCell(
                label: 'LR',
                value: metrics.lr!,
                labelStyle: labelStyle,
                valueStyle: valueStyle,
              ),
            if (metrics.throughputTokS != null) ...[
              const SizedBox(width: 16),
              _MetricCell(
                label: 'Throughput',
                value: '${_formatNumber(metrics.throughputTokS!)} tok/s',
                labelStyle: labelStyle,
                valueStyle: valueStyle,
              ),
            ],
            if (metrics.gpuMemGb != null) ...[
              const SizedBox(width: 16),
              _MetricCell(
                label: 'GPU Mem',
                value: '${metrics.gpuMemGb!.toStringAsFixed(1)} GB',
                labelStyle: labelStyle,
                valueStyle: valueStyle,
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),

        // Phase + perplexity
        Row(
          children: [
            if (metrics.phase != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _phaseColor(metrics.phase!).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _phaseColor(metrics.phase!).withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  metrics.phase!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _phaseColor(metrics.phase!),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (metrics.perplexity != null) ...[
              const SizedBox(width: 12),
              _MetricCell(
                label: 'Perplexity',
                value: metrics.perplexity!.toStringAsFixed(1),
                labelStyle: labelStyle,
                valueStyle: valueStyle,
              ),
            ],
            if (metrics.trend5ep != null) ...[
              const SizedBox(width: 12),
              _MetricCell(
                label: '5ep Trend',
                value: '${metrics.trend5ep! >= 0 ? '+' : ''}${metrics.trend5ep!.toStringAsFixed(4)}/ep',
                labelStyle: labelStyle,
                valueStyle: valueStyle?.copyWith(
                  color: metrics.trend5ep! < 0
                      ? const Color(0xFF4caf50)
                      : const Color(0xFFef5350),
                ),
              ),
            ],
          ],
        ),

        // Health flags
        if (metrics.flags.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: metrics.flags.map(_buildFlagChip).toList(),
          ),
        ],
      ],
    );
  }

  String? _lossDeltaSuffix() {
    if (metrics.lossDeltaPct == null || metrics.lossDirection == null) {
      return null;
    }
    final arrow = metrics.lossDirection == 'v' ? '\u2193' : '\u2191';
    return ' $arrow ${metrics.lossDeltaPct!.abs().toStringAsFixed(1)}%';
  }

  Color? _lossDeltaColor() {
    if (metrics.lossDirection == null) return null;
    return metrics.lossDirection == 'v'
        ? const Color(0xFF4caf50)
        : const Color(0xFFef5350);
  }

  static Color _phaseColor(String phase) {
    return switch (phase) {
      'WARMUP' => const Color(0xFFFFB74D),
      'ACTIVE' => const Color(0xFF4caf50),
      'CONVERGING' => const Color(0xFF42A5F5),
      'PLATEAU' => const Color(0xFFFF9800),
      'OVERFIT' => const Color(0xFFef5350),
      _ => AppColors.textMuted,
    };
  }

  static String _formatNumber(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k';
    }
    return '$n';
  }

  Widget _buildFlagChip(String flag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFef5350).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: const Color(0xFFef5350).withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        flag,
        style: const TextStyle(
          color: Color(0xFFef5350),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final String? suffix;
  final Color? suffixColor;

  const _MetricCell({
    required this.label,
    required this.value,
    this.labelStyle,
    this.valueStyle,
    this.suffix,
    this.suffixColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 1),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: valueStyle),
            if (suffix != null)
              Text(
                suffix!,
                style: valueStyle?.copyWith(
                  color: suffixColor,
                  fontSize: 10,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
