import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/api_config.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final _statusController = StreamController<Map<String, dynamic>>.broadcast();
  final Set<String> _subscriptions = {};
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _disposed = false;

  Stream<Map<String, dynamic>> get statusStream => _statusController.stream;

  bool get isConnected => _channel != null;

  void connect() {
    if (_disposed) return;
    _connectInternal();
  }

  void _connectInternal() {
    try {
      final uri = ApiConfig.wsUri('/ws/tasks/');
      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        (data) {
          _reconnectAttempts = 0;
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          _statusController.add(json);
        },
        onError: (error) {
          _channel = null;
          _scheduleReconnect();
        },
        onDone: () {
          _channel = null;
          _scheduleReconnect();
        },
      );

      // Re-subscribe to any tasks we were tracking
      for (final taskId in _subscriptions) {
        _send({'action': 'subscribe', 'task_id': taskId});
      }
    } catch (_) {
      _channel = null;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    final delay = Duration(
      seconds: (_reconnectAttempts * 2).clamp(1, 30),
    );
    _reconnectTimer = Timer(delay, _connectInternal);
  }

  void subscribe(String taskId) {
    _subscriptions.add(taskId);
    _send({'action': 'subscribe', 'task_id': taskId});
  }

  void unsubscribe(String taskId) {
    _subscriptions.remove(taskId);
    _send({'action': 'unsubscribe', 'task_id': taskId});
  }

  void _send(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _statusController.close();
    _subscriptions.clear();
  }
}
