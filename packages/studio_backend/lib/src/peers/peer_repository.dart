import 'package:drift/drift.dart';
import 'package:studio_backend/src/database/database.dart';
import 'package:studio_backend/src/database/postgres.dart';
import 'package:uuid/uuid.dart';

class PeerRepository {
  PeerRepository({required Database database}) : _database = database;

  final Database _database;

  Future<List<PeerConnectionEntity>> getAll() async {
    return (_database.select(_database.peerConnections)
          ..orderBy([(t) => OrderingTerm.desc(t.lastSeenAt)]))
        .get();
  }

  /// Create or update a peer connection record.
  /// If the public key already exists, updates `lastSeenAt` and increments
  /// `requestCount`. Otherwise inserts a new row.
  Future<void> upsert(String publicKey) async {
    final existing = await (_database.select(_database.peerConnections)
          ..where((t) => t.publicKey.equals(publicKey)))
        .getSingleOrNull();

    if (existing != null) {
      await (_database.update(_database.peerConnections)
            ..where((t) => t.id.equals(existing.id)))
          .write(
        PeerConnectionsCompanion(
          lastSeenAt: Value(DateTime.now().toPgDateTime()),
          requestCount: Value(existing.requestCount + 1),
        ),
      );
    } else {
      await _database.into(_database.peerConnections).insert(
        PeerConnectionsCompanion.insert(
          id: Value(const Uuid().v4()),
          publicKey: publicKey,
          requestCount: const Value(1),
        ),
      );
    }
  }

  Future<void> setBlocked(String id, {required bool blocked}) async {
    await (_database.update(_database.peerConnections)
          ..where((t) => t.id.equals(id)))
        .write(PeerConnectionsCompanion(blocked: Value(blocked)));
  }

  Future<bool> isBlocked(String publicKey) async {
    final row = await (_database.select(_database.peerConnections)
          ..where(
            (t) => t.publicKey.equals(publicKey) & t.blocked.equals(true),
          ))
        .getSingleOrNull();
    return row != null;
  }
}
