import 'package:studio_ui/configuration/configuration_base.dart';
import 'package:studio_ui/http/diskrot_http_client.dart';
import 'package:studio_ui/services/api_client.dart';

import 'fake_http_client.dart';

/// Creates an [ApiClient] backed by a [FakeHttpClient] for unit tests.
({ApiClient apiClient, FakeHttpClient fakeClient}) createTestApiClient() {
  final fakeClient = FakeHttpClient();
  final config = Configuration(
    buildEnvironment: BuildEnvironment.local,
    apiHost: 'localhost:8080',
    secure: false,
    applicationId: 'test',
  );
  final httpClient = DiskRotHttpClient(
    config,
    onAnonymousLoginRequired: () async {},
    httpClientFactory: () => fakeClient,
  );
  httpClient.userId = 'test-user';
  final apiClient = ApiClient(config: config, httpClient: httpClient);
  return (apiClient: apiClient, fakeClient: fakeClient);
}
