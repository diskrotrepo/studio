import 'package:studio_backend/src/settings/settings_repository.dart';

import '../../lib/src/cache/cache.dart';

import 'package:studio_backend/src/database/database.dart';
import 'package:studio_backend/src/database/postgres.dart';
import 'package:studio_backend/src/dependency_context.dart';
import 'package:studio_backend/src/health/health_service.dart';
import 'package:studio_backend/src/user/user_repository.dart';
import 'package:studio_backend/src/user/user_service.dart';
import 'package:uuid/uuid.dart';

import '../fake/fake_cache.dart';

late String testApplicationId;

Future<Database> setupTest() async {
  testApplicationId = const Uuid().v4();
  final database = Database(await initializePostgres());

  di.registerSingleton<UserRepository>(UserRepositoryImpl(database: database));

  setupRepositories(database);
  setupServices();



  return database;
}

void setupRepositories(Database database) {
  final Cache fakeCache = FakeCache();
  di.registerSingleton<Database>(database);
  di.registerSingleton<Cache>(fakeCache);
}

void setupServices() {
  di.registerSingleton(HealthService());

  di.registerSingleton<UserService>(
    UserService(userRepository: di.get<UserRepository>(), settingsRepository: di.get<SettingsRepository>()),
  );
}
