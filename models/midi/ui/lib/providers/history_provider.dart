import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task_status.dart';
import '../services/persistence_service.dart';
import 'generation_provider.dart';

class HistoryNotifier extends StateNotifier<List<TaskStatus>> {
  final PersistenceService _persistence;

  HistoryNotifier(this._persistence) : super(_persistence.loadHistory());

  void _save() => _persistence.saveHistory(state);

  void addTask(TaskStatus task) {
    state = [task, ...state];
    _save();
  }

  void updateTask(String taskId, TaskStatus updated) {
    state = [
      for (final t in state)
        if (t.taskId == taskId) updated else t,
    ];
    _save();
  }

  void removeTask(String taskId) {
    state = state.where((t) => t.taskId != taskId).toList();
    _save();
  }

  void markPlayed(String taskId) {
    state = [
      for (final t in state)
        if (t.taskId == taskId && !t.hasBeenPlayed)
          t.copyWith(hasBeenPlayed: true)
        else
          t,
    ];
    _save();
  }

  void toggleFavorite(String taskId) {
    state = [
      for (final t in state)
        if (t.taskId == taskId)
          t.copyWith(isFavorite: !t.isFavorite)
        else
          t,
    ];
    _save();
  }

  void clear() {
    state = [];
    _save();
  }
}

final historyProvider =
    StateNotifierProvider<HistoryNotifier, List<TaskStatus>>(
  (ref) => HistoryNotifier(ref.watch(persistenceServiceProvider)),
);
