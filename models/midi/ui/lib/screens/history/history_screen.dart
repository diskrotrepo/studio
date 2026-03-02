import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../models/task_status.dart';
import '../../providers/history_provider.dart';
import '../../providers/task_provider.dart';
import '../../widgets/task_status_card.dart';

enum _HistoryFilter { all, favorites, unplayed }

class HistoryScreen extends ConsumerStatefulWidget {
  final VoidCallback? onEditTrack;
  final void Function(TaskStatus task)? onExtendTrack;

  const HistoryScreen({super.key, this.onEditTrack, this.onExtendTrack});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  _HistoryFilter _filter = _HistoryFilter.all;

  List<TaskStatus> _applyFilter(List<TaskStatus> history) {
    return switch (_filter) {
      _HistoryFilter.all => history,
      _HistoryFilter.favorites => history.where((t) => t.isFavorite).toList(),
      _HistoryFilter.unplayed => history
          .where((t) => t.status == TaskState.complete && !t.hasBeenPlayed)
          .toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyProvider);
    final filtered = _applyFilter(history);
    final theme = Theme.of(context);

    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_note_outlined,
              size: 64,
              color: AppColors.border,
            ),
            const SizedBox(height: 16),
            Text(
              'No generations yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Submit a generation task to see it here',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${history.length} generation${history.length == 1 ? '' : 's'}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  ref.read(historyProvider.notifier).clear();
                },
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Clear'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final filter in _HistoryFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_filterLabel(filter)),
                    selected: _filter == filter,
                    onSelected: (_) => setState(() => _filter = filter),
                    selectedColor: AppColors.controlBlue.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.controlBlue,
                    side: BorderSide(
                      color: _filter == filter
                          ? AppColors.controlBlue
                          : AppColors.border,
                    ),
                    labelStyle: TextStyle(
                      color: _filter == filter
                          ? AppColors.controlBlue
                          : AppColors.textMuted,
                      fontSize: 12,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No ${_filterLabel(_filter).toLowerCase()} generations',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final task = filtered[index];
                    return _LiveTaskItem(
                      key: ValueKey(task.taskId),
                      task: task,
                      onEditTrack: widget.onEditTrack,
                      onExtendTrack: widget.onExtendTrack,
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _filterLabel(_HistoryFilter filter) {
    return switch (filter) {
      _HistoryFilter.all => 'All',
      _HistoryFilter.favorites => 'Favorites',
      _HistoryFilter.unplayed => 'Unplayed',
    };
  }
}

/// Each list item watches its own [taskStatusProvider] so that progress
/// updates only rebuild this single card, not the entire list.
class _LiveTaskItem extends ConsumerWidget {
  final TaskStatus task;
  final VoidCallback? onEditTrack;
  final void Function(TaskStatus task)? onExtendTrack;

  const _LiveTaskItem({
    super.key,
    required this.task,
    this.onEditTrack,
    this.onExtendTrack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pollingStatus = ref.watch(taskStatusProvider(task));
    final currentTask = pollingStatus.valueOrNull ?? task;
    return TaskStatusCard(
      task: currentTask,
      onEditTrack: onEditTrack,
      onExtendTrack: onExtendTrack,
    );
  }
}
