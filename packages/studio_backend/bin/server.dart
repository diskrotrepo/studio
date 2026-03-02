// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:studio_backend/src/audio/audio_service.dart';
import 'package:studio_backend/src/browse/browse_service.dart';
import 'package:studio_backend/src/database/database.dart';
import 'package:studio_backend/src/database/postgres.dart';
import 'package:studio_backend/src/dependency_context.dart';
import 'package:studio_backend/src/health/health_service.dart';
import 'package:studio_backend/src/logger/log_service.dart';
import 'package:studio_backend/src/logger/logger.dart';
import 'package:studio_backend/src/middleware/cors_middleware.dart';
import 'package:studio_backend/src/middleware/forwarding_middleware.dart';
import 'package:studio_backend/src/middleware/signature_middleware.dart';
import 'package:studio_backend/src/middleware/user_middleware.dart';
import 'package:studio_backend/src/peers/peer_repository.dart';
import 'package:studio_backend/src/peers/peer_service.dart';
import 'package:studio_backend/src/lyric_book/lyric_book_service.dart';
import 'package:studio_backend/src/workspaces/workspace_service.dart';
import 'package:studio_backend/src/user/user_repository.dart';
import 'package:studio_backend/src/server_backends/server_backend_repository.dart';
import 'package:studio_backend/src/server_backends/server_backend_service.dart';
import 'package:studio_backend/src/settings/settings_repository.dart';
import 'package:studio_backend/src/settings/settings_service.dart';
import 'package:studio_backend/src/text/text_service.dart';
import 'package:studio_backend/src/training/training_proxy_service.dart';
import 'package:studio_backend/src/user/user_service.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

typedef SigtermCallback = FutureOr<void> Function();

Future<void> main(List<String> args) async {
  await runZonedGuarded(
    () async {
      late Database database;

      database = Database(postgresQueryExecutor());

      await dependencySetup(database);

      // Generate and persist the server's external user ID on first start.
      final externalUserId =
          await di.get<SettingsRepository>().ensureExternalUserId();
      logger.d(message: 'External user ID: $externalUserId');

      final port = int.parse(Platform.environment['PORT'] ?? '80');

      final rootRouter = Router()
        ..mount('/v1/users', di.get<UserService>().router.call)
        ..mount('/v1/health', di.get<HealthService>().router.call);


      if (di.isRegistered<AudioService>()) {
        rootRouter.mount('/v1/audio', di.get<AudioService>().router.call);
      }

      if (di.isRegistered<TextService>()) {
        rootRouter.mount('/v1/text', di.get<TextService>().router.call);
      }

      if (di.isRegistered<TrainingProxyService>()) {
        final trainingProxy = di.get<TrainingProxyService>();
        rootRouter.mount(
          '/v1/dataset',
          trainingProxy.datasetRouter.call,
        );
        rootRouter.mount(
          '/v1/training',
          trainingProxy.trainingRouter.call,
        );
      }

      rootRouter.mount(
        '/v1/settings',
        di.get<SettingsService>().router.call,
      );

      rootRouter.mount(
        '/v1/server-backends',
        di.get<ServerBackendService>().router.call,
      );

      rootRouter.mount(
        '/v1/peers',
        di.get<PeerService>().router.call,
      );

      rootRouter.mount(
        '/v1/logs',
        di.get<LogService>().router.call,
      );

      rootRouter.mount(
        '/v1/browse',
        di.get<BrowseService>().router.call,
      );

      rootRouter.mount(
        '/v1/workspaces',
        di.get<WorkspaceService>().router.call,
      );

      rootRouter.mount(
        '/v1/lyric-book',
        di.get<LyricBookService>().router.call,
      );

      final handler = const Pipeline()
          .addMiddleware(_ignoreFavicon())
          .addMiddleware(_logUnhandledErrors())
          .addMiddleware(logRequests())
          .addMiddleware(corsMiddleware(
            allowedOrigins: Platform.environment['CORS_ALLOWED_ORIGINS']
                ?.split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList(),
          ))
          .addMiddleware(signatureVerificationMiddleware(
            peerRepository: di.get<PeerRepository>(),
            settingsRepository: di.get<SettingsRepository>(),
          ))
          .addMiddleware(forwardingMiddleware(
            serverBackendRepository: di.get<ServerBackendRepository>(),
            settingsRepository: di.get<SettingsRepository>(),
          ))
          .addMiddleware(userAutoCreateMiddleware(di.get<UserRepository>()))
          .addHandler(rootRouter.call);

      logger.d(message: 'Serving on port: $port');

      await shelf_io.serve(
        handler,
        InternetAddress.anyIPv4,
        port,
        shared: true,
      );
    },
    (error, stackTrace) {
      logger.e(
        message: 'Uncaught zone error',
        error: error,
        stackTrace: stackTrace,
      );
    },
  );
}

Middleware _logUnhandledErrors() {
  return (Handler inner) {
    return (Request request) async {
      try {
        return await Future.sync(() => inner(request));
      } catch (error, stackTrace) {
        logger.e(
          message:
              'Unhandled exception for ${request.method} ${request.requestedUri}',
          error: error,
          stackTrace: stackTrace,
        );
        rethrow;
      }
    };
  };
}

Middleware _ignoreFavicon() {
  return (Handler inner) {
    return (Request request) async {
      if (request.url.path == 'favicon.ico') {
        return Response(204);
      }
      return inner(request);
    };
  };
}
