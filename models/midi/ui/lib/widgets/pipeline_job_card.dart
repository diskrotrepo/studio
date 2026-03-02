import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task_status.dart';
import '../providers/task_provider.dart';
import '../theme/app_theme.dart';
import 'diagnosis_log_panel.dart';
import 'training_metrics_panel.dart';
import 'training_summary_panel.dart';

/// Reusable job card for pipeline tasks (pretokenize, download, training).
///
/// Watches [taskStatusProvider] to display live progress, status, and errors.
class PipelineJobCard extends ConsumerWidget {
  final TaskStatus task;

  const PipelineJobCard({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final live = ref.watch(taskStatusProvider(task));

    return live.when(
      data: (t) => _buildCard(context, theme, t),
      loading: () => _buildCard(context, theme, task),
      error: (_, __) => _buildCard(context, theme, task),
    );
  }

  Widget _buildCard(BuildContext context, ThemeData theme, TaskStatus t) {
    final Color borderColor;
    final Color bgColor;
    final IconData icon;
    final Color iconColor;

    switch (t.status) {
      case TaskState.pending:
        borderColor = AppColors.border;
        bgColor = AppColors.surfaceHigh;
        icon = Icons.schedule;
        iconColor = AppColors.textMuted;
      case TaskState.processing:
        borderColor = const Color(0xFF1565C0);
        bgColor = const Color(0xFF0d1b2a);
        icon = Icons.sync;
        iconColor = const Color(0xFF42A5F5);
      case TaskState.complete:
        borderColor = const Color(0xFF2d5a2d);
        bgColor = const Color(0xFF1a2e1a);
        icon = Icons.check_circle;
        iconColor = const Color(0xFF4caf50);
      case TaskState.failed:
        borderColor = const Color(0xFF5a2d2d);
        bgColor = const Color(0xFF2e1a1a);
        icon = Icons.error;
        iconColor = const Color(0xFFef5350);
      case TaskState.unknown:
        borderColor = AppColors.border;
        bgColor = AppColors.surfaceHigh;
        icon = Icons.help_outline;
        iconColor = AppColors.textMuted;
    }

    final timeAgo = _formatTimeAgo(t.submittedAt);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(
                t.taskId.length > 12
                    ? t.taskId.substring(0, 12)
                    : t.taskId,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
              if (_stageLabel(t) != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _stageColor(t).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _stageColor(t).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    _stageLabel(t)!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _stageColor(t),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                timeAgo,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          if (t.status == TaskState.complete &&
              t.trainingSummary != null) ...[
            const SizedBox(height: 8),
            TrainingSummaryPanel(summary: t.trainingSummary!),
          ] else if (t.metrics != null) ...[
            const SizedBox(height: 8),
            TrainingMetricsPanel(metrics: t.metrics!),
          ] else if (t.outputLines != null &&
              t.outputLines!.isNotEmpty) ...[
            const SizedBox(height: 8),
            DiagnosisLogPanel(lines: t.outputLines!),
          ] else if (t.status == TaskState.processing) ...[
            const SizedBox(height: 8),
            if (t.progress != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: t.progress,
                  minHeight: 4,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation(
                      Color(0xFF42A5F5)),
                ),
              ),
            if (t.message != null) ...[
              const SizedBox(height: 4),
              Text(
                t.message!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
          if (t.status == TaskState.failed && t.error != null) ...[
            const SizedBox(height: 6),
            Text(
              t.error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFFef5350),
                fontSize: 11,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  static String? _stageLabel(TaskStatus t) {
    if (t.metrics?.phase != null) return t.metrics!.phase;
    return switch (t.status) {
      TaskState.pending => 'QUEUED',
      TaskState.processing => _shortMessage(t.message),
      TaskState.complete => 'DONE',
      TaskState.failed => 'FAILED',
      TaskState.unknown => null,
    };
  }

  static String? _shortMessage(String? message) {
    if (message == null) return 'STARTING';
    final lower = message.toLowerCase();
    if (lower.contains('loading') || lower.contains('preparing')) {
      return 'LOADING';
    }
    if (lower.contains('tokeniz')) return 'TOKENIZING';
    if (lower.contains('validat')) return 'VALIDATING';
    if (lower.contains('download')) return 'DOWNLOADING';
    if (lower.contains('epoch')) return 'TRAINING';
    if (lower.contains('diagnos')) return 'DIAGNOSING';
    return 'RUNNING';
  }

  static Color _stageColor(TaskStatus t) {
    if (t.metrics?.phase != null) {
      return switch (t.metrics!.phase!) {
        'WARMUP' => const Color(0xFFFFB74D),
        'ACTIVE' => const Color(0xFF4caf50),
        'CONVERGING' => const Color(0xFF42A5F5),
        'PLATEAU' => const Color(0xFFFF9800),
        'OVERFIT' => const Color(0xFFef5350),
        _ => AppColors.textMuted,
      };
    }
    return switch (t.status) {
      TaskState.pending => AppColors.textMuted,
      TaskState.processing => const Color(0xFF42A5F5),
      TaskState.complete => const Color(0xFF4caf50),
      TaskState.failed => const Color(0xFFef5350),
      TaskState.unknown => AppColors.textMuted,
    };
  }

  static String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
