import 'package:drift/drift.dart';

@DataClassName('AppSettingEntity')
class AppSettings extends Table {
  @override
  String get tableName => 'app_settings';

  TextColumn get key => text()();

  TextColumn get value => text().nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {key};
}
