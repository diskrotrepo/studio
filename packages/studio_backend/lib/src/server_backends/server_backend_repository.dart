import 'package:drift/drift.dart';
import 'package:studio_backend/src/database/database.dart';
import 'package:uuid/uuid.dart';

class ServerBackendRepository {
  ServerBackendRepository({required Database database}) : _database = database;

  final Database _database;

  Future<List<ServerBackendEntity>> getAll() async {
    return (_database.select(_database.serverBackends)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<ServerBackendEntity?> getActive() async {
    return (_database.select(_database.serverBackends)
          ..where((t) => t.isActive.equals(true)))
        .getSingleOrNull();
  }

  Future<ServerBackendEntity> create({
    required String name,
    required String apiHost,
    required bool secure,
  }) async {
    final id = Uuid().v4();
    await _database.into(_database.serverBackends).insert(
      ServerBackendsCompanion.insert(
        id: Value(id),
        name: name,
        apiHost: apiHost,
        secure: Value(secure),
        isActive: const Value(false),
      ),
    );
    return (_database.select(_database.serverBackends)
          ..where((t) => t.id.equals(id)))
        .getSingle();
  }

  Future<void> update({
    required String id,
    String? name,
    String? apiHost,
    bool? secure,
  }) async {
    await (_database.update(_database.serverBackends)
          ..where((t) => t.id.equals(id)))
        .write(
      ServerBackendsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        apiHost: apiHost != null ? Value(apiHost) : const Value.absent(),
        secure: secure != null ? Value(secure) : const Value.absent(),
      ),
    );
  }

  Future<void> deactivate(String id) async {
    await (_database.update(_database.serverBackends)
          ..where((t) => t.id.equals(id)))
        .write(const ServerBackendsCompanion(isActive: Value(false)));
  }

  Future<void> delete(String id) async {
    await (_database.delete(_database.serverBackends)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  Future<void> setActive(String id) async {
    await _database.transaction(() async {
      // Deactivate all
      await (_database.update(_database.serverBackends)).write(
        const ServerBackendsCompanion(isActive: Value(false)),
      );
      // Activate the selected one
      await (_database.update(_database.serverBackends)
            ..where((t) => t.id.equals(id)))
          .write(const ServerBackendsCompanion(isActive: Value(true)));
    });
  }
}
