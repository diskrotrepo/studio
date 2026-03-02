// ignore_for_file: prefer_const_constructors

import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_postgres/drift_postgres.dart';
import 'package:studio_backend/src/logger/logger.dart' show logger;
import 'package:studio_backend/src/test/utils.dart';
import 'package:platform/platform.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

Map<String, PgInstance> _instances = {};

class PgInstance {
  PgInstance({
    required this.connection,
    required this.database,
    required this.containerId,
  });

  final Connection connection;
  final PgDatabase database;
  final String containerId;
}

Future<void> ensurePostgresMigrated(GeneratedDatabase database) async {
  try {
    await database.doWhenOpened((e) => null);
  } catch (e, s) {
    logger.e(message: 'Failed to open database.', error: e, stackTrace: s);
    rethrow;
  }
  await database.close();
}

QueryExecutor postgresQueryExecutor({
  bool logStatements = false,
  PostgresEnvironment? environment,
}) {
  final postgresEnv = environment ?? PostgresEnvironment();
  return DatabaseConnection(
    PgDatabase(
      settings: const ConnectionSettings(sslMode: SslMode.disable),

      logStatements: logStatements,
      endpoint: Endpoint(
        host: postgresEnv.host,
        database: postgresEnv.database,
        username: postgresEnv.username,
        password: postgresEnv.password,
      ),
    ),
  );
}

class PostgresEnvironment {
  PostgresEnvironment([Platform platform = const LocalPlatform()])
    : host = _env(platform, 'POSTGRES_HOST'),
      database = _env(platform, 'POSTGRES_DATABASE'),
      username = _env(platform, 'POSTGRES_USER'),
      password = _env(platform, 'POSTGRES_PASSWORD');

  static String _env(Platform platform, String key) {
    if (!platform.environment.containsKey(key)) {
      throw PostgresEnvironmentNotFoundError(key: key);
    }
    return platform.environment[key]!;
  }

  final String host;
  final String database;
  final String username;
  final String password;
}

class PostgresEnvironmentNotFoundError extends Error {
  PostgresEnvironmentNotFoundError({required this.key});

  final String key;

  @override
  String toString() {
    return 'PostgresEnvironmentNotFoundError: Missing environment detail for $key';
  }
}

extension DateTimeExt on DateTime {
  PgDate toPgDate() {
    return PgDate.fromDateTime(this);
  }

  PgDateTime toPgDateTime() {
    return PgDateTime(this);
  }
}

extension PgDateTimeExt on PgDateTime? {
  DateTime? get asDateTime {
    final v = this;
    if (v == null) return null;

    return DateTime.parse(v.toString());
  }
}

class BaseTable extends Table {
  TextColumn get id => text().clientDefault(() => Uuid().v4())();

  TimestampColumn get createdAt => customType(
    PgTypes.timestampNoTimezone,
  ).clientDefault(() => DateTime.now().toPgDateTime())();

  @override
  Set<Column<Object>>? get primaryKey => {id};

  TextColumn get userId => text().withLength(min: 1, max: 100)();
}

extension GeneratedDatabaseExtension on GeneratedDatabase {
  Future<void> customStatements(String statements) async {
    for (final statement
        in statements
            .split(';')
            .map((e) => e.trim())
            .where((element) => element.isNotEmpty)) {
      await customStatement(statement);
    }
  }
}

Future<PgDatabase> initializePostgres({bool logStatements = false}) async {
  final instance = await createPostgresInstance(logStatements: logStatements);
  return instance.database;
}

Future<void> _doesDockerExist() async {
  final result = await Process.run('docker', ['version']);
  if (result.exitCode != 0) {
    throw Exception('Docker is not installed or not running: ${result.stderr}');
  }
}

Future<PgInstance> createPostgresInstance({bool logStatements = false}) async {
  await _doesDockerExist();

  late String containerId;
  final connection = await getUnusedPort((port) async {
    printOnFailure('Trying to start Postgres on: $port');
    final result = await _startPostgres(port: port);
    if (result == null || result.exitCode != 0) {
      return null;
    }

    containerId = result.stdout.toString().trim();
    final endpoint = Endpoint(
      host: 'localhost',
      database: 'postgres',
      username: 'postgres',
      password: 'postgres',
      port: port,
    );
    const connectionSettings = ConnectionSettings(sslMode: SslMode.disable);

    try {
      return await _retry(() async {
        final connection = await Connection.open(
          endpoint,
          settings: connectionSettings,
        );
        printOnFailure('Postgres started on port: ${endpoint.port}');

        return connection;
      });
    } catch (e) {
      printOnFailure('Retry fail for Postgres on port: $port');
      await _pgTearDown(containerId);
      return null;
    }
  });

  if (connection == null) {
    fail('Failed to start Postgres');
  }

  addTearDown(() => _pgTearDown(containerId));

  final database = PgDatabase.opened(connection, logStatements: logStatements);
  final instance = PgInstance(
    connection: connection,
    database: database,
    containerId: containerId,
  );
  _instances[containerId] = instance;
  return instance;
}

Future<void> _pgTearDown(String containerId) async {
  final result = await Process.run('docker', ['kill', containerId]);
  if (result.exitCode != 0) {
    fail('Failed to stop Postgres: ${result.stderr}');
  }
  final instance = _instances.remove(containerId);
  await instance?.connection.close();
}

Future<ProcessResult?> _startPostgres({int port = 5432}) async {
  final tmp = Directory.systemTemp;
  return _retry(() async {
    final result = await Process.run('docker', [
      'run',
      '--rm',
      '-d',
      '-p',
      '$port:5432',
      '-v',
      '${tmp.path}:/tmp',
      '-e',
      'POSTGRES_PASSWORD=postgres',
      'postgres',
    ]);
    // ignore: avoid_print
    print(result.stderr);
    if (result.exitCode != 0) {
      throw Exception('Failed to start Postgres: ${result.stderr}');
    }
    return result;
  });
}

typedef RetryMethod<T> = FutureOr<T> Function();

Future<T?> _retry<T>(
  RetryMethod<T> method, {
  int maximum = 30,
  Duration delay = const Duration(milliseconds: 200),
}) async {
  final result = await runZonedGuarded(
    () async {
      int count = 0;
      while (true) {
        count += 1;
        try {
          return await method();
        } catch (e) {
          if (count >= maximum) {
            rethrow;
          }

          await Future.delayed(delay);
        }
      }
    },
    (error, stack) {
      printOnFailure('''
Error encountered while retrying:
$error
$stack
''');
    },
  );
  return result;
}
