import 'package:studio_backend/src/cache/cache.dart';

class FakeCache extends Cache {
  final Map<String, dynamic> _store = {};

  @override
  Future<void> close() async {
    _store.clear();
  }

  @override
  Future<int> dec({required String key}) async {
    final value = _store[key];
    if (value is int) {
      _store[key] = value - 1;
      return value - 1;
    }
    throw UnimplementedError();
  }

  @override
  Future<int> inc({required String key}) async {
    final value = _store[key];
    if (value is int) {
      _store[key] = value + 1;
      return value + 1;
    }

    return 0;
  }

  @override
  Future<void> initializeCache() async {
    throw UnimplementedError();
  }

  @override
  Future<T> protect<T>(
    String resource,
    CriticalSection<T> criticalSection, {
    Duration ttl = const Duration(seconds: 10),
    int? numberOfRetries,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> publish(String channel, Object message) async {

    throw UnimplementedError();
  }

  @override
  Future<List<String>> scan({required String pattern}) async {

    throw UnimplementedError();
  }

  @override
  Stream<List> subscribe(String channel) async* {

    throw UnimplementedError();
  }

  @override
  Future<void> delete({required String key}) async {
    _store.remove(key);
  }

  @override
  Future<dynamic> get({required String key}) async {
    return _store[key];
  }

  @override
  Future<void> set({
    required String key,
    required dynamic value,
    Duration? ttl,
  }) async {
    _store[key] = value;
  }
}
