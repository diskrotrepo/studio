import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tags_response.dart';
import 'api_client_provider.dart';

final tagsProvider = FutureProvider<TagsResponse>((ref) {
  return ref.read(apiClientProvider).getTags();
});
