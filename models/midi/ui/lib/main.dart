import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'config/api_config.dart';
import 'providers/generation_provider.dart';
import 'services/persistence_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final persistence = PersistenceService(prefs);

  final savedUrl = persistence.loadServerUrl();
  if (savedUrl != null) {
    ApiConfig.baseUrl = savedUrl;
  }

  runApp(
    ProviderScope(
      overrides: [
        persistenceServiceProvider.overrideWithValue(persistence),
      ],
      child: const MidiApp(),
    ),
  );
}
