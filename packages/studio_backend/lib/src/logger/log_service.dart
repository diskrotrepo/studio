import 'package:studio_backend/src/logger/buffer_log_writer.dart';
import 'package:studio_backend/src/utils/shelf_helper.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class LogService {
  LogService({required BufferLogWriter bufferLogWriter})
      : _buffer = bufferLogWriter;

  final BufferLogWriter _buffer;

  Router get router {
    final r = Router();
    r.get('/', _getLogs);
    return r;
  }

  Future<Response> _getLogs(Request request) async {
    return jsonOk({'data': _buffer.entries});
  }
}
