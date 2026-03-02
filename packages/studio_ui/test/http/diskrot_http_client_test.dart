import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:studio_ui/configuration/configuration_base.dart';
import 'package:studio_ui/http/diskrot_http_client.dart';

import '../helpers/fake_http_client.dart';

void main() {
  late DiskRotHttpClient client;
  late FakeHttpClient fakeHttp;

  setUp(() {
    fakeHttp = FakeHttpClient();
    final config = Configuration(
      buildEnvironment: BuildEnvironment.local,
      apiHost: 'localhost:8080',
      secure: false,
      applicationId: 'test-app',
    );
    client = DiskRotHttpClient(
      config,
      onAnonymousLoginRequired: () async {},
      httpClientFactory: () => fakeHttp,
    );
  });

  group('DiskRotHttpClient.get', () {
    test('sends GET with base headers', () async {
      fakeHttp.respondJson({'ok': true});
      await client.get(endpoint: '/test');
      expect(fakeHttp.lastRequest!.method, 'GET');
      expect(fakeHttp.lastRequest!.headers['Accept'], 'application/json');
      expect(
          fakeHttp.lastRequest!.headers['Diskrot-Project-Id'], 'test-app');
    });

    test('builds correct URI without TLS', () async {
      fakeHttp.respondJson({'ok': true});
      await client.get(endpoint: '/test');
      expect(fakeHttp.lastRequest!.url.scheme, 'http');
      expect(fakeHttp.lastRequest!.url.host, 'localhost');
      expect(fakeHttp.lastRequest!.url.port, 8080);
      expect(fakeHttp.lastRequest!.url.path, '/v1/test');
    });

    test('includes query parameters', () async {
      fakeHttp.respondJson({'ok': true});
      await client.get(endpoint: '/test', query: {'key': 'val'});
      expect(fakeHttp.lastRequest!.url.queryParameters['key'], 'val');
    });

    test('merges extra headers', () async {
      fakeHttp.respondJson({'ok': true});
      await client.get(
          endpoint: '/test', headers: {'X-Custom': 'value'});
      expect(fakeHttp.lastRequest!.headers['X-Custom'], 'value');
      // Base headers still present.
      expect(fakeHttp.lastRequest!.headers['Accept'], 'application/json');
    });
  });

  group('DiskRotHttpClient.post', () {
    test('sends POST with JSON body and content-type', () async {
      fakeHttp.respondJson({'ok': true});
      await client.post(endpoint: '/test', data: {'foo': 'bar'});
      expect(fakeHttp.lastRequest!.method, 'POST');
      expect(
        fakeHttp.lastRequest!.headers['Content-Type'],
        'application/json',
      );
    });
  });

  group('DiskRotHttpClient.put', () {
    test('sends PUT request', () async {
      fakeHttp.respondJson({'ok': true});
      await client.put(endpoint: '/test', data: {'a': 1});
      expect(fakeHttp.lastRequest!.method, 'PUT');
    });
  });

  group('DiskRotHttpClient.patch', () {
    test('sends PATCH request', () async {
      fakeHttp.respondJson({'ok': true});
      await client.patch(endpoint: '/test', data: {'b': 2});
      expect(fakeHttp.lastRequest!.method, 'PATCH');
    });
  });

  group('DiskRotHttpClient.delete', () {
    test('sends DELETE request', () async {
      fakeHttp.respondJson({'ok': true});
      await client.delete(endpoint: '/test');
      expect(fakeHttp.lastRequest!.method, 'DELETE');
    });
  });

  group('DiskRotHttpClient.postOctetStream', () {
    test('sends raw bytes with octet-stream content type', () async {
      fakeHttp.respondJson({'ok': true});
      await client.postOctetStream(
        endpoint: '/upload',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      expect(fakeHttp.lastRequest!.method, 'POST');
      expect(
        fakeHttp.lastRequest!.headers['Content-Type'],
        'application/octet-stream',
      );
    });
  });

  group('DiskRotHttpClient.putBytes', () {
    test('sends PUT with raw bytes', () async {
      fakeHttp.respondJson({'ok': true});
      await client.putBytes(
        endpoint: '/upload',
        bytes: Uint8List.fromList([4, 5, 6]),
      );
      expect(fakeHttp.lastRequest!.method, 'PUT');
    });
  });

  group('userId propagation', () {
    test('includes Diskrot-User-Id header when set', () async {
      client.userId = 'user-123';
      fakeHttp.respondJson({'ok': true});
      await client.get(endpoint: '/test');
      expect(fakeHttp.lastRequest!.headers['Diskrot-User-Id'], 'user-123');
    });
  });

  group('HTTPS URI building', () {
    test('uses https scheme when secure is true', () async {
      final secureConfig = Configuration(
        buildEnvironment: BuildEnvironment.prod,
        apiHost: 'api.example.com',
        secure: true,
        applicationId: 'test-app',
      );
      final secureClient = DiskRotHttpClient(
        secureConfig,
        onAnonymousLoginRequired: () async {},
        httpClientFactory: () => fakeHttp,
      );
      fakeHttp.respondJson({'ok': true});
      await secureClient.get(endpoint: '/test');
      expect(fakeHttp.lastRequest!.url.scheme, 'https');
      expect(fakeHttp.lastRequest!.url.host, 'api.example.com');
    });
  });
}
