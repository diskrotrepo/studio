import 'package:drift/drift.dart';
import 'package:studio_backend/src/database/postgres.dart';

@DataClassName('UserEntity')
class User extends BaseTable {
  @override
  String get tableName => 'users';

  TextColumn get displayName => text().withLength(min: 1, max: 100).unique()();
}
