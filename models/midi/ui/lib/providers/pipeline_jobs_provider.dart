import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task_status.dart';

class PipelineJobsNotifier extends StateNotifier<List<TaskStatus>> {
  PipelineJobsNotifier() : super([]);

  void addJob(TaskStatus task) {
    state = [task, ...state];
  }
}

final pipelineJobsProvider =
    StateNotifierProvider<PipelineJobsNotifier, List<TaskStatus>>(
  (ref) => PipelineJobsNotifier(),
);
