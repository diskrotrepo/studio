import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client_provider.dart';

/// Auto-disposes so the models list is re-fetched each time the generate
/// page is entered, picking up newly available checkpoints without a restart.
final modelsProvider = FutureProvider.autoDispose<List<String>>((ref) {
  return ref.read(apiClientProvider).getModels();
});
