import 'package:drift/drift.dart';
import 'package:drift_postgres/drift_postgres.dart';
import 'package:studio_backend/src/database/postgres.dart';
import 'package:uuid/uuid.dart';

@DataClassName('LyricSheetEntity')
class LyricSheets extends Table {
  @override
  String get tableName => 'lyric_sheets';

  TextColumn get id => text().clientDefault(() => Uuid().v4())();

  TimestampColumn get createdAt => customType(
    PgTypes.timestampNoTimezone,
  ).clientDefault(() => DateTime.now().toPgDateTime())();

  TextColumn get userId => text().withLength(min: 1, max: 100)();

  TextColumn get title => text().withDefault(const Constant(''))();

  TextColumn get content => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}
