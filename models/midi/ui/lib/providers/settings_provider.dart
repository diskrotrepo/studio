import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart';
import 'generation_provider.dart';

final serverUrlProvider = StateProvider<String>((ref) {
  return ApiConfig.baseUrl;
});

void updateServerUrl(WidgetRef ref, String url) {
  // Normalise: strip trailing slash
  final normalised = url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  ApiConfig.baseUrl = normalised;
  ref.read(serverUrlProvider.notifier).state = normalised;
  ref.read(persistenceServiceProvider).saveServerUrl(normalised);
}
