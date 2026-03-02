// ignore_for_file: avoid_dynamic_calls
import 'dart:async';
import 'dart:math';

import 'package:studio_backend/src/logger/logger.dart';
import 'package:redis/redis.dart' as redis;
import 'package:resp_client/resp_client.dart';
import 'package:shorebird_redis_client/shorebird_redis_client.dart';
import 'package:uuid/uuid.dart';

typedef CriticalSection<T> = FutureOr<T> Function();

class RedisCacheImpl implements Cache {
  RedisCacheImpl({required this.host});

  final String host;
  final Random random = Random();
  RedisClient? _redisClient;

  redis.PubSub? _pubSub;
  redis.Command? _pubSubCommand;
  redis.Command? _command;
  StreamController<List<dynamic>>? _pubSubController;

  Set<String> channels = {};

  @override
  Future<T> protect<T>(
    String resource,
    CriticalSection<T> criticalSection, {
    Duration ttl = const Duration(seconds: 10),
    int? numberOfRetries,
  }) async {
    final stopwatch = Stopwatch()..start();
    final key = 'lock:$resource';
    final value = const Uuid().v4();
    final command = ['SET', key, value, 'NX', 'PX', ttl.inMilliseconds];

    int retries = 0;
    String? result;
    while (true) {
      result = await _redisClient!.execute(command) as String?;
      if (result != 'OK') {
        if (numberOfRetries != null && retries++ >= numberOfRetries) {
          throw Exception('Lock $resource is busy');
        }
        logger.d(
          message:
              'Lock $resource is busy '
              '(${stopwatch.elapsedMilliseconds}ms)',
        );
        await Future.delayed(Duration(milliseconds: random.nextInt(100)));
        continue;
      }

      try {
        return await criticalSection();
      } finally {
        final currentValue = await _redisClient!.get(key: key);
        if (currentValue == value) {
          await _redisClient!.delete(key: key);
        }
        stopwatch.stop();
        logger.d(
          message: 'Lock $resource took ${stopwatch.elapsedMilliseconds}ms',
        );
      }
    }
  }

  @override
  Future<void> initializeCache() async {
    _redisClient = await _initializeRedis(host);

    final redisConnection = redis.RedisConnection();
    _command = await redisConnection.connect(host, 6379);
  }

  @override
  Future<dynamic> get({required String key}) async {
    return await _redisClient!.get(key: key);
  }

  @override
  Future<void> set({
    required String key,
    required dynamic value,
    Duration? ttl,
  }) async {
    await _redisClient!.set(key: key, value: value.toString(), ttl: ttl);
  }

  @override
  Future<List<String>> scan({required String pattern}) async {
    final results = <String>[];
    String? cursor;
    while (cursor != '0') {
      final result = await _redisClient!.execute([
        'SCAN',
        cursor ?? '0',
        'MATCH',
        pattern,
      ]);
      cursor = (result[0] as RespBulkString).payload;
      final respArray = result[1] as RespArray;
      final elements = respArray.payload?.map((e) => e.payload.toString());
      if (elements != null) {
        results.addAll(elements);
      }
    }
    return results;
  }

  @override
  Future<void> delete({required String key}) async {
    await _redisClient!.delete(key: key);
  }

  @override
  Future<void> close() async {
    await _pubSubController?.close();
    await _redisClient?.close();
    await _pubSubCommand?.get_connection().close();
    await _command?.get_connection().close();
  }

  @override
  Stream<List> subscribe(String channel) async* {
    await _initializePubSubCommand();
    _pubSub!.subscribe([channel]);
    channels.add(channel);

    StreamSubscription? subscription;
    _pubSubController ??= StreamController.broadcast(
      onListen: () {
        subscription = _pubSub!.getStream().cast<List<dynamic>>().listen(
          _pubSubController!.add,
          onError: _pubSubController!.addError,
          onDone: _pubSubController!.close,
        );
      },
      onCancel: () {
        _pubSub?.unsubscribe(channels.toList());
        channels.clear();
        subscription?.cancel();
        _pubSubController = null;
      },
    );
    yield* _pubSubController!.stream.where((e) {
      return e[0] == 'message' && e[1] == channel;
    });
  }

  @override
  Future<void> publish(String channel, Object message) async {
    await _redisClient?.execute(['PUBLISH', channel, message]);
  }

  @override
  Future<int> dec({required String key}) async {
    await _redisClient!.execute(['DECR', key]);
    final value = await _redisClient!.get(key: key);

    if (value == null) {
      throw Exception('Key $key not found');
    }

    return int.tryParse(value)!;
  }

  @override
  Future<int> inc({required String key}) async {
    await _redisClient!.execute(['INCR', key]);
    final value = await _redisClient!.get(key: key);

    if (value == null) {
      throw Exception('Key $key not found');
    }

    return int.tryParse(value)!;
  }

  Future<RedisClient> _initializeRedis(String? host) async {
    if (host == null) {
      throw Exception('Missing definition REDIS_HOST');
    }

    final redisClient = RedisClient(socket: RedisSocketOptions(host: host));
    await redisClient.connect();
    return redisClient;
  }

  Future<void> _initializePubSubCommand() async {
    if (_pubSub != null) {
      return;
    }
    final redisConnection = redis.RedisConnection();
    _pubSubCommand = await redisConnection.connect(host, 6379);
    _pubSub = redis.PubSub(_pubSubCommand!);
  }
}

abstract class Cache {
  Future<void> initializeCache();

  Future<dynamic> get({required String key});
  Future<void> set({
    required String key,
    required dynamic value,
    Duration? ttl,
  });

  Future<List<String>> scan({required String pattern});

  Future<int> dec({required String key});

  Future<int> inc({required String key});

  Future<void> delete({required String key});

  Future<void> close();

  Stream<List<dynamic>> subscribe(String channel);

  Future<void> publish(String channel, Object message);

  Future<T> protect<T>(
    String resource,
    CriticalSection<T> criticalSection, {
    Duration ttl = const Duration(seconds: 10),
    int? numberOfRetries,
  });
}
