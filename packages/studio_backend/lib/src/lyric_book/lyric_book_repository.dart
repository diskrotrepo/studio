import 'package:drift/drift.dart';
import 'package:studio_backend/src/database/database.dart';
import 'package:uuid/uuid.dart';

class LyricBookRepository {
  LyricBookRepository({required Database database}) : _database = database;

  final Database _database;

  Future<List<LyricSheetEntity>> getAllByUserId(String userId) async {
    return (_database.select(_database.lyricSheets)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<LyricSheetEntity?> getById(String id) async {
    return (_database.select(_database.lyricSheets)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<LyricSheetEntity> create({
    required String userId,
    required String title,
    String content = '',
  }) async {
    final id = const Uuid().v4();
    await _database.into(_database.lyricSheets).insert(
      LyricSheetsCompanion.insert(
        id: Value(id),
        userId: userId,
        title: Value(title),
        content: Value(content),
      ),
    );
    return (_database.select(_database.lyricSheets)
          ..where((t) => t.id.equals(id)))
        .getSingle();
  }

  Future<void> update({
    required String id,
    String? title,
    String? content,
  }) async {
    await (_database.update(_database.lyricSheets)
          ..where((t) => t.id.equals(id)))
        .write(LyricSheetsCompanion(
      title: title != null ? Value(title) : const Value.absent(),
      content: content != null ? Value(content) : const Value.absent(),
    ));
  }

  Future<void> delete(String id) async {
    await (_database.delete(_database.lyricSheets)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  Future<List<LyricSheetEntity>> search({
    required String userId,
    required String query,
  }) async {
    final pattern = '%$query%';
    return (_database.select(_database.lyricSheets)
          ..where((t) =>
              t.userId.equals(userId) &
              (t.title.lower().like(pattern.toLowerCase()) |
                  t.content.lower().like(pattern.toLowerCase())))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }
}
