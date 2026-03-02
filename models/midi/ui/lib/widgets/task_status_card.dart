import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/generation_params.dart';
import '../models/picked_file.dart';
import '../models/task_status.dart';
import '../providers/audio_provider.dart';
import '../providers/api_client_provider.dart';
import '../providers/edit_file_provider.dart';
import '../providers/history_provider.dart';
import '../theme/app_theme.dart';
import '../utils/file_saver.dart';
import 'audio_scrubber.dart';

class TaskStatusCard extends ConsumerStatefulWidget {
  final TaskStatus task;
  final VoidCallback? onEditTrack;
  final void Function(TaskStatus task)? onExtendTrack;

  const TaskStatusCard({
    super.key,
    required this.task,
    this.onEditTrack,
    this.onExtendTrack,
  });

  @override
  ConsumerState<TaskStatusCard> createState() => _TaskStatusCardState();
}

class _TaskStatusCardState extends ConsumerState<TaskStatusCard> {
  bool _isConverting = false;
  bool _showDetails = false;

  TaskStatus get task => widget.task;
  VoidCallback? get onEditTrack => widget.onEditTrack;
  void Function(TaskStatus task)? get onExtendTrack => widget.onExtendTrack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentlyPlaying = ref.watch(currentlyPlayingTaskProvider);
    final isThisPlaying = currentlyPlaying == task.taskId;

    final isInProgress =
        task.status == TaskState.pending || task.status == TaskState.processing;

    final isComplete = task.status == TaskState.complete;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: isInProgress
          ? AppColors.inProgressSurface
          : isComplete
              ? AppColors.completedSurface
              : const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isInProgress
            ? const BorderSide(color: AppColors.inProgressBorder, width: 1)
            : isComplete
                ? const BorderSide(color: AppColors.completedBorder, width: 1)
                : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatusIcon(status: task.status, progress: task.progress),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (task.status == TaskState.complete && !task.hasBeenPlayed)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: const BoxDecoration(
                                color: AppColors.controlBlue,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              task.taskId,
                              style: theme.textTheme.titleSmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (task.tagsUsed != null && task.tagsUsed!.isNotEmpty)
                        Text(
                          task.tagsUsed!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (task.params != null)
                        GestureDetector(
                          onTap: () => setState(() => _showDetails = !_showDetails),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _paramsLabel(task.params!),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                _showDetails ? Icons.expand_less : Icons.expand_more,
                                size: 16,
                                color: AppColors.textMuted,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (task.status == TaskState.complete)
                  IconButton(
                    onPressed: () {
                      ref.read(historyProvider.notifier).toggleFavorite(task.taskId);
                    },
                    icon: Icon(
                      task.isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: task.isFavorite ? AppColors.brand : AppColors.textMuted,
                      size: 20,
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: task.isFavorite ? 'Unfavorite' : 'Favorite',
                  ),
                const SizedBox(width: 4),
                Text(
                  _statusLabel(task.status),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: _statusColor(task.status, theme),
                  ),
                ),
              ],
            ),
            if (_showDetails && task.params != null) _buildDetailsPanel(theme),
            if (task.status == TaskState.processing) ...[
              const SizedBox(height: 12),
              TweenAnimationBuilder<double>(
                tween: Tween(end: task.progress ?? 0.0),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                builder: (context, value, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: task.progress != null ? value : null,
                    minHeight: 6,
                    backgroundColor: AppColors.inProgressTrack,
                    color: AppColors.controlBlue,
                  ),
                ),
              ),
              if (task.message != null) ...[
                const SizedBox(height: 6),
                Text(
                  task.message!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
            if (task.status == TaskState.complete) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  if (task.mp3DownloadUrl != null || task.downloadUrl != null)
                    FilledButton.icon(
                      onPressed: _isConverting ? null : () => _playAudio(ref, context),
                      icon: _isConverting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(isThisPlaying ? Icons.pause : Icons.play_arrow, size: 18),
                      label: Text(_isConverting ? 'Converting...' : (isThisPlaying ? 'Pause' : 'Play')),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.controlBlue,
                      ),
                    ),
                  if (task.downloadUrl != null)
                    OutlinedButton.icon(
                      onPressed: () => _downloadFile(ref, context, task.downloadUrl!, 'mid'),
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('MIDI'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  if (task.mp3DownloadUrl != null)
                    OutlinedButton.icon(
                      onPressed: () => _downloadFile(ref, context, task.mp3DownloadUrl!, 'mp3'),
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('MP3'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  if (task.downloadUrl != null && onEditTrack != null && !kIsWeb)
                    OutlinedButton.icon(
                      onPressed: () => _editTrack(ref, context),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  if (task.downloadUrl != null && onExtendTrack != null && !kIsWeb)
                    OutlinedButton.icon(
                      onPressed: () => onExtendTrack!(task),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Extend'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                      ),
                    ),
                ],
              ),
              if (isThisPlaying) const AudioScrubber(),
            ],
            if (task.status == TaskState.failed && task.error != null) ...[
              const SizedBox(height: 8),
              Text(
                task.error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _playAudio(WidgetRef ref, BuildContext context) async {
    final audio = ref.read(audioServiceProvider);
    final api = ref.read(apiClientProvider);
    final currentlyPlaying = ref.read(currentlyPlayingTaskProvider);

    if (currentlyPlaying == task.taskId) {
      if (audio.isPlaying) {
        await audio.pause();
      } else {
        await audio.play();
      }
      return;
    }

    try {
      String? mp3Url = task.mp3DownloadUrl;

      // Convert MIDI to MP3 if no MP3 is available
      if (mp3Url == null && task.downloadUrl != null) {
        setState(() => _isConverting = true);
        try {
          final midiBytes = await api.downloadFile(task.downloadUrl!);
          mp3Url = await api.convertMidiBytes(midiBytes);

          // Cache the MP3 URL in history so we don't re-convert
          ref.read(historyProvider.notifier).updateTask(
            task.taskId,
            task.copyWith(mp3DownloadUrl: mp3Url),
          );
        } finally {
          if (mounted) setState(() => _isConverting = false);
        }
      }

      if (mp3Url == null) return;

      final url = api.getDownloadUrl(mp3Url);
      await audio.stop();
      await audio.loadUrl(url);
      await audio.play();
      ref.read(currentlyPlayingTaskProvider.notifier).state = task.taskId;
      ref.read(historyProvider.notifier).markPlayed(task.taskId);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to play: $e')),
        );
      }
    }
  }

  Future<void> _editTrack(WidgetRef ref, BuildContext context) async {
    try {
      final api = ref.read(apiClientProvider);
      final bytes = await api.downloadFile(task.downloadUrl!);

      ref.read(editFileProvider.notifier).state = PickedFile(
        bytes: bytes,
        name: 'edit_${task.taskId.substring(0, 8)}.mid',
      );
      onEditTrack?.call();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load for editing: $e')),
        );
      }
    }
  }

  Future<void> _downloadFile(
    WidgetRef ref,
    BuildContext context,
    String downloadPath,
    String extension,
  ) async {
    try {
      final api = ref.read(apiClientProvider);
      final bytes = await api.downloadFile(downloadPath);
      final filename = 'generated_${task.taskId.substring(0, 8)}.$extension';
      final path = await saveFile(bytes, filename);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(path != null ? 'Saved to $path' : 'Download started')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }


  String _statusLabel(TaskState status) {
    if (status == TaskState.processing && task.progress != null) {
      return '${(task.progress! * 100).toInt()}%';
    }
    return switch (status) {
      TaskState.pending => 'Pending',
      TaskState.processing => 'Generating...',
      TaskState.complete => 'Complete',
      TaskState.failed => 'Failed',
      TaskState.unknown => 'Unknown',
    };
  }

  Widget _buildDetailsPanel(ThemeData theme) {
    final p = task.params!;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: AppColors.textMuted,
      fontSize: 10,
      letterSpacing: 0.5,
    );
    final valueStyle = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      fontSize: 12,
    );
    final headerStyle = theme.textTheme.labelSmall?.copyWith(
      color: AppColors.controlBlue,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.0,
    );

    Widget stat(String label, String value) {
      return SizedBox(
        width: 100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: labelStyle),
            const SizedBox(height: 2),
            Text(value, style: valueStyle),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PARAMETERS', style: headerStyle),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: [
                stat('Model', p.model),
                stat('Duration', '${p.duration}s'),
                stat('BPM', '${p.bpm}'),
                stat('Temperature', '${p.temperature}'),
                stat('Top-K', '${p.topK}'),
                stat('Top-P', '${p.topP}'),
                stat('Rep. Penalty', '${p.repetitionPenalty}'),
                if (p.seed != null) stat('Seed', '${p.seed}'),
                if (p.humanize != null) stat('Humanize', p.humanize!),
                if (p.extendFrom != null) stat('Extend From', '${p.extendFrom}s'),
              ],
            ),
            const SizedBox(height: 12),
            Text('STATISTICS', style: headerStyle),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: [
                stat('Audio Length', _formatDurationMmSs(p.duration)),
                stat('Type', task.generationType),
                stat('Submitted', _formatTime(task.submittedAt)),
                if (task.completedAt != null)
                  stat('Gen. Time', _formatElapsed(task.completedAt!.difference(task.submittedAt))),
                stat('Status', _statusLabel(task.status)),
                if (task.progress != null)
                  stat('Progress', '${(task.progress! * 100).toStringAsFixed(1)}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDurationMmSs(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatElapsed(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    }
    return '${d.inSeconds}s';
  }

  String _formatTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _paramsLabel(GenerationParams p) {
    final parts = <String>[
      '${p.bpm} BPM',
      '${p.duration}s',
      'temp ${p.temperature}',
      if (p.model != 'default') p.model,
    ];
    return parts.join(' \u00b7 ');
  }

  Color _statusColor(TaskState status, ThemeData theme) {
    return switch (status) {
      TaskState.pending => AppColors.controlBlue.withValues(alpha: 0.7),
      TaskState.processing => AppColors.controlBlue,
      TaskState.complete => Colors.green,
      TaskState.failed => theme.colorScheme.error,
      TaskState.unknown => AppColors.textMuted,
    };
  }
}

class _StatusIcon extends StatelessWidget {
  final TaskState status;
  final double? progress;

  const _StatusIcon({required this.status, this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return switch (status) {
      TaskState.pending => SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.controlBlue.withValues(alpha: 0.6),
          ),
        ),
      TaskState.processing => SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            value: progress,
            color: AppColors.controlBlue,
          ),
        ),
      TaskState.complete => const Icon(Icons.check_circle, color: Colors.green, size: 24),
      TaskState.failed => Icon(Icons.error, color: theme.colorScheme.error, size: 24),
      TaskState.unknown => const Icon(Icons.help_outline, color: AppColors.textMuted, size: 24),
    };
  }
}
