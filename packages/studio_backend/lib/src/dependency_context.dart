import 'dart:convert';
import 'dart:io';

import 'package:get_it/get_it.dart';
import 'package:studio_backend/src/browse/browse_service.dart';
import 'package:studio_backend/src/audio/ace_step_15/ace_step_15_client.dart';
import 'package:studio_backend/src/audio/bark/bark_client.dart';
import 'package:studio_backend/src/audio/ltx/ltx_client.dart';
import 'package:studio_backend/src/audio/midi/midi_client.dart';
import 'package:studio_backend/src/audio/audio_client.dart';
import 'package:studio_backend/src/audio/audio_generation_task_repository.dart';
import 'package:studio_backend/src/audio/audio_model_client.dart';
import 'package:studio_backend/src/audio/audio_service.dart';
import 'package:studio_backend/src/cache/cache.dart';
import 'package:studio_backend/src/database/database.dart';
import 'package:studio_backend/src/health/health_service.dart';
import 'package:studio_backend/src/storage/cloud_storage.dart';
import 'package:studio_backend/src/storage/local_storage.dart';
import 'package:studio_backend/src/text/text_client.dart';
import 'package:studio_backend/src/text/text_model_client.dart';
import 'package:studio_backend/src/peers/peer_repository.dart';
import 'package:studio_backend/src/peers/peer_service.dart';
import 'package:studio_backend/src/server_backends/server_backend_repository.dart';
import 'package:studio_backend/src/server_backends/server_backend_service.dart';
import 'package:studio_backend/src/settings/settings_repository.dart';
import 'package:studio_backend/src/settings/settings_service.dart';
import 'package:studio_backend/src/text/text_service.dart';
import 'package:studio_backend/src/text/yulan_mini/yulan_mini_client.dart';
import 'package:studio_backend/src/training/training_proxy_service.dart';
import 'package:studio_backend/src/crypto/key_generator.dart';
import 'package:studio_backend/src/logger/buffer_log_writer.dart';
import 'package:studio_backend/src/logger/log_service.dart';
import 'package:studio_backend/src/logger/logger.dart';
import 'package:studio_backend/src/user/user_repository.dart';
import 'package:studio_backend/src/user/user_service.dart';
import 'package:studio_backend/src/lyric_book/lyric_book_repository.dart';
import 'package:studio_backend/src/lyric_book/lyric_book_service.dart';
import 'package:studio_backend/src/workspaces/workspace_repository.dart';
import 'package:studio_backend/src/workspaces/workspace_service.dart';

final di = GetIt.I;

Future<void> dependencySetup(Database database) async {
  final redisHost = Platform.environment['REDIS_HOST'];

  if (redisHost == null) {
    throw ArgumentError.notNull('REDIS_HOST');
  }

  final Cache cache = RedisCacheImpl(host: redisHost);
  await cache.initializeCache();

  di.registerSingleton<Database>(database);
  di.registerSingleton<Cache>(cache);
  di.registerSingleton<CloudStorage>(LocalStorage());

  di.registerSingleton<UserRepository>(UserRepositoryImpl(database: database));

  di.registerSingleton<SettingsRepository>(
    SettingsRepository(database: database),
  );

  // Generate server keypair on first start
  final settingsRepo = di.get<SettingsRepository>();
  final existingKey = await settingsRepo.getServerPublicKey();
  if (existingKey == null) {
    logger.i(message: 'No server keypair found. Generating RSA 2048-bit keypair...');
    final keyPair = generateRsaKeyPair();
    await settingsRepo.setServerKeys(keyPair.publicKeyPem, keyPair.privateKeyPem);
    logger.i(message: 'Server keypair generated and stored.');
  } else {
    logger.i(message: 'Server keypair already exists.');
  }

  // Attach in-memory log buffer to the logger.
  final bufferLogWriter = BufferLogWriter();
  logger.addWriter(bufferLogWriter);
  di.registerSingleton<BufferLogWriter>(bufferLogWriter);
  di.registerSingleton<LogService>(LogService(bufferLogWriter: bufferLogWriter));

  // Services

  di.registerSingleton(HealthService());
  final browseRoots = Platform.environment['BROWSE_ALLOWED_ROOTS']
      ?.split(Platform.isWindows ? ';' : ':');
  di.registerSingleton(BrowseService(allowedRoots: browseRoots));

  di.registerSingleton<UserService>(
    UserService(
      userRepository: di.get<UserRepository>(),
      settingsRepository: di.get<SettingsRepository>(),
    ),
  );

  di.registerSingleton<AudioGenerationTaskRepository>(
    AudioGenerationTaskRepositoryImpl(database: database),
  );
  di.registerSingleton<SettingsService>(
    SettingsService(settingsRepository: di.get<SettingsRepository>()),
  );

  di.registerSingleton<ServerBackendRepository>(
    ServerBackendRepository(database: database),
  );
  di.registerSingleton<ServerBackendService>(
    ServerBackendService(repository: di.get<ServerBackendRepository>()),
  );

  di.registerSingleton<PeerRepository>(
    PeerRepository(database: database),
  );
  di.registerSingleton<PeerService>(
    PeerService(repository: di.get<PeerRepository>()),
  );

  di.registerSingleton<WorkspaceRepository>(
    WorkspaceRepository(database: database),
  );
  di.registerSingleton<WorkspaceService>(
    WorkspaceService(repository: di.get<WorkspaceRepository>()),
  );

  di.registerSingleton<LyricBookRepository>(
    LyricBookRepository(database: database),
  );
  di.registerSingleton<LyricBookService>(
    LyricBookService(
      repository: di.get<LyricBookRepository>(),
      taskRepository: di.get<AudioGenerationTaskRepository>(),
    ),
  );

  // Audio generation (multi-model endpoints)
  final audioModelsJson = Platform.environment['AUDIO_MODELS'] ?? '';
  if (audioModelsJson.isNotEmpty) {
    final audioModels = (jsonDecode(audioModelsJson) as Map<String, dynamic>)
        .cast<String, String>();
    final audioApiKey = Platform.environment['AUDIO_API_KEY'];

    final modelClients = <String, AudioModelClient>{
      if (audioModels.containsKey('ace_step_15'))
        'ace_step_15': AceStep15Client(
          baseUrl: audioModels['ace_step_15']!,
          apiKey: audioApiKey,
        ),
      if (audioModels.containsKey('bark'))
        'bark': BarkClient(
          baseUrl: audioModels['bark']!,
          apiKey: audioApiKey,
        ),
      if (audioModels.containsKey('midi'))
        'midi': MidiClient(
          baseUrl: audioModels['midi']!,
          apiKey: audioApiKey,
        ),
      if (audioModels.containsKey('ltx'))
        'ltx': LtxClient(
          baseUrl: audioModels['ltx']!,
          apiKey: audioApiKey,
        ),
    };

    final disabledModelsRaw =
        Platform.environment['DISABLED_MODELS'] ?? '';
    final disabledModels = disabledModelsRaw.isEmpty
        ? <String>{}
        : disabledModelsRaw.split(',').map((s) => s.trim()).toSet();

    di.registerSingleton<AudioClient>(
      AudioClient(
        modelClients: modelClients,
        disabledModels: disabledModels,
      ),
    );

    final studioBucket =
        Platform.environment['DISKROT_STUDIO_BUCKET'] ?? 'studio';

    di.registerSingleton<AudioService>(
      AudioService(
        audioClient: di.get<AudioClient>(),
        cache: di.get<Cache>(),
        studioBucket: studioBucket,
        audioGenerationTaskRepository: di.get<AudioGenerationTaskRepository>(),
        cloudStorage: di.get<CloudStorage>(),
      ),
    );

    // Seed default system prompts for each audio model if not yet present.
    await settingsRepo.ensureDefaultPrompts(modelClients.keys.toList());

    // Training proxy – forward dataset/training routes to the ACE-Step server.
    final aceStepUrl = audioModels['ace_step_15'];
    if (aceStepUrl != null) {
      di.registerSingleton<TrainingProxyService>(
        TrainingProxyService(baseUrl: aceStepUrl, apiKey: audioApiKey),
      );
    }
  }

  // Text generation (multi-model endpoints)
  final textModelsJson = Platform.environment['TEXT_MODELS'] ?? '';
  if (textModelsJson.isNotEmpty) {
    final textModels = (jsonDecode(textModelsJson) as Map<String, dynamic>)
        .cast<String, String>();
    final textApiKey = Platform.environment['TEXT_API_KEY'];

    final textModelClients = <String, TextModelClient>{
      if (textModels.containsKey('yulan_mini'))
        'yulan_mini': YuLanMiniClient(
          baseUrl: textModels['yulan_mini']!,
          apiKey: textApiKey,
        ),
    };

    di.registerSingleton<TextClient>(
      TextClient(modelClients: textModelClients),
    );
    di.registerSingleton<TextService>(
      TextService(
        textClient: di.get<TextClient>(),
        settingsRepository: di.get<SettingsRepository>(),
      ),
    );
  }
}
