import 'package:drift/drift.dart';
import 'package:drift_postgres/drift_postgres.dart';
import 'package:studio_backend/src/database/postgres.dart';
import 'package:uuid/uuid.dart';

@DataClassName('WorkspaceEntity')
class Workspaces extends Table {
  @override
  String get tableName => 'workspaces';

  TextColumn get id => text().clientDefault(() => Uuid().v4())();

  TimestampColumn get createdAt => customType(
    PgTypes.timestampNoTimezone,
  ).clientDefault(() => DateTime.now().toPgDateTime())();

  TextColumn get userId => text().withLength(min: 1, max: 100)();

  TextColumn get name => text().withLength(min: 1, max: 100)();

  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}
