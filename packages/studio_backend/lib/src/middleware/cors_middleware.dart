import 'package:shelf/shelf.dart';

const _defaultAllowedOrigins = [
  'http://localhost:3000',
  'http://127.0.0.1:3000',
];

const _allowMethods = 'GET, POST, PUT, PATCH, DELETE, OPTIONS';
const _allowHeaders =
    'Origin, Content-Type, Authorization, Diskrot-Api-Key, Diskrot-Project-Id, '
    'Diskrot-User-Id, Content-Length, Connection, X-Session-Url, '
    'X-Content-Type, X-Content-Range, Diskrot-File-Id, X-Total-Size';

Middleware corsMiddleware({List<String>? allowedOrigins}) {
  final origins = allowedOrigins ?? _defaultAllowedOrigins;

  String resolveOrigin(String? requestOrigin) {
    // No configured origins → wildcard (backwards-compatible default).
    if (origins.isEmpty) return '*';
    if (requestOrigin != null && origins.contains(requestOrigin)) {
      return requestOrigin;
    }
    return origins.first;
  }

  return (Handler innerHandler) {
    return (Request request) async {
      final origin = resolveOrigin(request.headers['origin']);

      if (request.method == 'OPTIONS') {
        return Response.ok(
          '',
          headers: {
            'Access-Control-Allow-Origin': origin,
            'Access-Control-Allow-Methods': _allowMethods,
            'Access-Control-Allow-Headers': _allowHeaders,
          },
        );
      }

      final response = await innerHandler(request);
      return response.change(
        headers: {
          ...response.headers,
          'Access-Control-Allow-Origin': origin,
          'Access-Control-Allow-Methods': _allowMethods,
          'Access-Control-Allow-Headers': _allowHeaders,
        },
      );
    };
  };
}
