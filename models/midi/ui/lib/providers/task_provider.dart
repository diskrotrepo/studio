import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task_status.dart';
import '../services/websocket_service.dart';
import 'api_client_provider.dart';
import 'history_provider.dart';

/// Shared WebSocket service singleton.
final websocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  service.connect();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Streams task status updates via WebSocket push, falling back to HTTP
/// polling if the WebSocket is unavailable or disconnects.
final taskStatusProvider =
    StreamProvider.family<TaskStatus, TaskStatus>((ref, initial) async* {
  ref.keepAlive();

  final ws = ref.read(websocketServiceProvider);
  final api = ref.read(apiClientProvider);

  yield initial;

  // Try WebSocket-based push first
  ws.subscribe(initial.taskId);

  // Filter the shared stream to only this task's updates, throttled so
  // rapid progress ticks don't cause excessive widget rebuilds.
  final taskStream = ws.statusStream
      .where((json) => json['task_id'] == initial.taskId);

  // Listen for push updates with a timeout — if nothing arrives within
  // 5 seconds we fall back to polling (server may not support WS yet).
  DateTime lastEmit = DateTime.fromMillisecondsSinceEpoch(0);
  const throttle = Duration(milliseconds: 500);

  try {
    await for (final json in taskStream.timeout(
      const Duration(seconds: 5),
    )) {
      final status = initial.withUpdate(json);

      // Always emit terminal states immediately; throttle progress updates
      final now = DateTime.now();
      if (status.isTerminal || now.difference(lastEmit) >= throttle) {
        lastEmit = now;
        yield status;
      }

      // Only persist terminal states to history (progress is ephemeral)
      if (status.isTerminal) {
        ref.read(historyProvider.notifier).updateTask(initial.taskId, status);
      }

      if (status.isTerminal) {
        ws.unsubscribe(initial.taskId);
        return;
      }
    }
  } on TimeoutException {
    // WebSocket didn't deliver in time — fall through to polling
  } catch (_) {
    // WebSocket error — fall through to polling
  }

  ws.unsubscribe(initial.taskId);

  // ---- HTTP polling fallback ----
  int consecutiveErrors = 0;
  const maxErrors = 5;

  while (true) {
    try {
      final json = await api.getTaskStatus(initial.taskId);
      consecutiveErrors = 0;

      final status = initial.withUpdate(json);
      yield status;

      if (status.isTerminal) {
        ref.read(historyProvider.notifier).updateTask(initial.taskId, status);
      }

      if (status.isTerminal) break;

      final delay = status.status == TaskState.pending
          ? const Duration(seconds: 2)
          : const Duration(seconds: 1);
      await Future.delayed(delay);
    } catch (e) {
      consecutiveErrors++;
      if (consecutiveErrors >= maxErrors) {
        final errorStatus = TaskStatus(
          taskId: initial.taskId,
          status: TaskState.failed,
          error: 'Lost connection to server',
          submittedAt: initial.submittedAt,
          generationType: initial.generationType,
          tagsUsed: initial.tagsUsed,
        );
        yield errorStatus;
        ref
            .read(historyProvider.notifier)
            .updateTask(initial.taskId, errorStatus);
        break;
      }
      await Future.delayed(Duration(seconds: consecutiveErrors * 2));
    }
  }
});
