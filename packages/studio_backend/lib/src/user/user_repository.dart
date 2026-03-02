import 'package:drift/drift.dart';
import 'package:studio_backend/src/database/database.dart';
import 'package:studio_backend/src/user/dto/user_record.dart';
import 'package:uuid/uuid.dart';

class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl({required Database database}) : _database = database;

  final Database _database;

  @override
  Future<void> deleteUser({required String id}) {
    throw UnimplementedError();
  }

  @override
  Future<User> createUser({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final id = const Uuid().v4();

    await _database.user.insertOnConflictUpdate(
      UserCompanion(id: Value(id), displayName: Value(displayName)),
    );

    return User(uid: id, displayName: displayName, createdAt: DateTime.now());
  }

  @override
  Future<void> updateUser({
    required String userId,
    required String email,
    required String password,
    required String displayName,
  }) async {
    await (_database.update(
      _database.user,
    )..where((t) => t.id.equals(userId))).write(
      UserCompanion(displayName: Value(displayName)),
    );
  }

  @override
  Future<UserEntity?> getUser({required String userId}) async {
    final result = await (_database.select(
      _database.user,
    )..where((t) => t.id.equals(userId))).getSingleOrNull();

    return result;
  }

  @override
  Future<void> ensureUser({required String externalUserId}) async {
    final existing = await (_database.select(_database.user)
          ..where((t) => t.userId.equals(externalUserId)))
        .getSingleOrNull();

    if (existing != null) return;

    await _database.user.insertOnConflictUpdate(
      UserCompanion(
        userId: Value(externalUserId),
        displayName: Value('User ${externalUserId.substring(0, 8)}'),
      ),
    );
  }
}

abstract class UserRepository {
  Future<User> createUser({
    required String email,
    required String password,
    required String displayName,
  });
  Future<void> updateUser({
    required String userId,
    required String email,
    required String password,
    required String displayName,
  });
  Future<void> deleteUser({required String id});
  Future<UserEntity?> getUser({required String userId});
  Future<void> ensureUser({required String externalUserId});
}
