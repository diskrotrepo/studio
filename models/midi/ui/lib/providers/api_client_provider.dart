import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  ref.onDispose(() => client.dispose());
  return client;
});
