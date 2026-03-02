import 'package:shelf/shelf.dart';
import 'package:studio_backend/src/middleware/cors_middleware.dart';
import 'package:test/test.dart';

void main() {
  group('corsMiddleware', () {
    test('OPTIONS request returns 200 with CORS headers', () async {
      final handler = const Pipeline()
          .addMiddleware(
              corsMiddleware(allowedOrigins: ['http://localhost:3000']))
          .addHandler((request) => Response.ok('ok'));

      final request = Request(
        'OPTIONS',
        Uri.parse('http://localhost/test'),
        headers: {'origin': 'http://localhost:3000'},
      );

      final response = await handler(request);

      expect(response.statusCode, 200);
      expect(response.headers['Access-Control-Allow-Origin'],
          'http://localhost:3000');
      expect(response.headers['Access-Control-Allow-Methods'],
          contains('GET'));
      expect(response.headers['Access-Control-Allow-Headers'],
          contains('Content-Type'));
    });

    test('regular GET request includes CORS headers in response', () async {
      final handler = const Pipeline()
          .addMiddleware(
              corsMiddleware(allowedOrigins: ['http://localhost:3000']))
          .addHandler((request) => Response.ok('ok'));

      final request = Request(
        'GET',
        Uri.parse('http://localhost/test'),
        headers: {'origin': 'http://localhost:3000'},
      );

      final response = await handler(request);

      expect(response.statusCode, 200);
      expect(response.headers['Access-Control-Allow-Origin'],
          'http://localhost:3000');
      expect(response.headers['Access-Control-Allow-Methods'], isNotNull);
      expect(response.headers['Access-Control-Allow-Headers'], isNotNull);
    });

    test('allowed origin is reflected in Access-Control-Allow-Origin',
        () async {
      final handler = const Pipeline()
          .addMiddleware(corsMiddleware(
              allowedOrigins: [
                'http://localhost:3000',
                'http://example.com',
              ]))
          .addHandler((request) => Response.ok('ok'));

      final request = Request(
        'GET',
        Uri.parse('http://localhost/test'),
        headers: {'origin': 'http://example.com'},
      );

      final response = await handler(request);

      expect(response.headers['Access-Control-Allow-Origin'],
          'http://example.com');
    });

    test('unknown origin falls back to first allowed origin', () async {
      final handler = const Pipeline()
          .addMiddleware(corsMiddleware(
              allowedOrigins: [
                'http://localhost:3000',
                'http://example.com',
              ]))
          .addHandler((request) => Response.ok('ok'));

      final request = Request(
        'GET',
        Uri.parse('http://localhost/test'),
        headers: {'origin': 'http://evil.com'},
      );

      final response = await handler(request);

      expect(response.headers['Access-Control-Allow-Origin'],
          'http://localhost:3000');
    });

    test('empty allowed origins list returns wildcard', () async {
      final handler = const Pipeline()
          .addMiddleware(corsMiddleware(allowedOrigins: []))
          .addHandler((request) => Response.ok('ok'));

      final request = Request(
        'GET',
        Uri.parse('http://localhost/test'),
        headers: {'origin': 'http://anything.com'},
      );

      final response = await handler(request);

      expect(response.headers['Access-Control-Allow-Origin'], '*');
    });

    test('default origins include localhost:3000', () async {
      final handler = const Pipeline()
          .addMiddleware(corsMiddleware())
          .addHandler((request) => Response.ok('ok'));

      final request = Request(
        'GET',
        Uri.parse('http://localhost/test'),
        headers: {'origin': 'http://localhost:3000'},
      );

      final response = await handler(request);

      expect(response.headers['Access-Control-Allow-Origin'],
          'http://localhost:3000');
    });

    test('default origins include 127.0.0.1:3000', () async {
      final handler = const Pipeline()
          .addMiddleware(corsMiddleware())
          .addHandler((request) => Response.ok('ok'));

      final request = Request(
        'GET',
        Uri.parse('http://localhost/test'),
        headers: {'origin': 'http://127.0.0.1:3000'},
      );

      final response = await handler(request);

      expect(response.headers['Access-Control-Allow-Origin'],
          'http://127.0.0.1:3000');
    });
  });
}
