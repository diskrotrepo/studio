import 'package:drift/drift.dart';
import 'package:drift_postgres/drift_postgres.dart';
import 'package:studio_backend/src/database/postgres.dart';
import 'package:uuid/uuid.dart';

@DataClassName('PeerConnectionEntity')
class PeerConnections extends Table {
  @override
  String get tableName => 'peer_connections';

  TextColumn get id => text().clientDefault(() => Uuid().v4())();

  TextColumn get publicKey => text().unique()();

  TimestampColumn get firstSeenAt => customType(
        PgTypes.timestampNoTimezone,
      ).clientDefault(() => DateTime.now().toPgDateTime())();

  TimestampColumn get lastSeenAt => customType(
        PgTypes.timestampNoTimezone,
      ).clientDefault(() => DateTime.now().toPgDateTime())();

  IntColumn get requestCount => integer().withDefault(const Constant(0))();

  BoolColumn get blocked => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}
