import 'package:drift/drift.dart';
import 'package:studio_backend/src/database/database.dart';
import 'package:uuid/uuid.dart';

class WorkspaceRepository {
  WorkspaceRepository({required Database database}) : _database = database;

  final Database _database;

  Future<List<WorkspaceEntity>> getAllByUserId(String userId) async {
    return (_database.select(_database.workspaces)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<WorkspaceEntity?> getDefaultByUserId(String userId) async {
    return (_database.select(_database.workspaces)
          ..where(
              (t) => t.userId.equals(userId) & t.isDefault.equals(true)))
        .getSingleOrNull();
  }

  Future<WorkspaceEntity?> getById(String id) async {
    return (_database.select(_database.workspaces)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<WorkspaceEntity> create({
    required String userId,
    required String name,
    bool isDefault = false,
  }) async {
    final id = const Uuid().v4();
    await _database.into(_database.workspaces).insert(
      WorkspacesCompanion.insert(
        id: Value(id),
        userId: userId,
        name: name,
        isDefault: Value(isDefault),
      ),
    );
    return (_database.select(_database.workspaces)
          ..where((t) => t.id.equals(id)))
        .getSingle();
  }

  Future<void> rename({required String id, required String name}) async {
    await (_database.update(_database.workspaces)
          ..where((t) => t.id.equals(id)))
        .write(WorkspacesCompanion(name: Value(name)));
  }

  Future<void> delete(String id) async {
    await (_database.delete(_database.workspaces)
          ..where((t) => t.id.equals(id) & t.isDefault.equals(false)))
        .go();
  }

  Future<WorkspaceEntity> ensureDefault(String userId) async {
    final existing = await getDefaultByUserId(userId);
    if (existing != null) return existing;
    return create(userId: userId, name: 'My Workspace', isDefault: true);
  }

  Future<void> backfillSongsWithoutWorkspace({
    required String userId,
    required String workspaceId,
  }) async {
    await (_database.update(_database.audioGenerationTask)
          ..where(
              (t) => t.userId.equals(userId) & t.workspaceId.isNull()))
        .write(AudioGenerationTaskCompanion(
          workspaceId: Value(workspaceId),
        ));
  }

  Future<void> reassignSongs({
    required String fromWorkspaceId,
    required String toWorkspaceId,
  }) async {
    await (_database.update(_database.audioGenerationTask)
          ..where((t) => t.workspaceId.equals(fromWorkspaceId)))
        .write(AudioGenerationTaskCompanion(
          workspaceId: Value(toWorkspaceId),
        ));
  }
}
