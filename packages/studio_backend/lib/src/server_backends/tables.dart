import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:drift_postgres/drift_postgres.dart';
import 'package:studio_backend/src/database/postgres.dart';

@DataClassName('ServerBackendEntity')
class ServerBackends extends Table {
  @override
  String get tableName => 'server_backends';

  TextColumn get id => text().clientDefault(() => Uuid().v4())();

  TimestampColumn get createdAt => customType(
    PgTypes.timestampNoTimezone,
  ).clientDefault(() => DateTime.now().toPgDateTime())();

  TextColumn get name => text().withLength(min: 1, max: 100)();

  TextColumn get apiHost => text().withLength(min: 1, max: 255)();

  BoolColumn get secure => boolean().withDefault(const Constant(false))();

  BoolColumn get isActive => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}
