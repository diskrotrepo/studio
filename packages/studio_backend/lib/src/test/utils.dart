import 'dart:async';
import 'dart:io';

Future<T> getUnusedPort<T extends Object?>(
  FutureOr<T> Function(int port) tryPort,
) async {
  T? value;
  await Future.doWhile(() async {
    final int port;
    try {
      port = await getUnsafeUnusedPort();
    } on SocketException {
      /// Keep trying to find an unused port.
      return true;
    }

    value = await tryPort(port);
    return value == null;
  });
  return value as T;
}

Future<int> getUnsafeUnusedPort() async {
  final socket = await RawServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();

  return port;
}
