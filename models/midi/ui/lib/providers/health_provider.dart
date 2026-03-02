import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/health_status.dart';
import 'api_client_provider.dart';

final healthProvider = FutureProvider<HealthStatus>((ref) {
  return ref.read(apiClientProvider).getHealth();
});
