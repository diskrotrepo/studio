import 'package:drift/drift.dart';
import 'package:drift_postgres/drift_postgres.dart';
import 'package:studio_backend/src/database/postgres.dart';

@DataClassName('AudioGenerationTaskEntity')
class AudioGenerationTask extends BaseTable {
  @override
  String get tableName => 'audio_generation_tasks';

  // ---- core request fields ----
  TextColumn get model => text()();
  TextColumn get taskType => text()();

  // ---- content fields ----
  TextColumn get prompt => text().nullable()();
  TextColumn get lyrics => text().nullable()();
  TextColumn get negativePrompt => text().nullable()();

  // ---- source audio fields ----
  TextColumn get srcAudioPath => text().nullable()();
  RealColumn get infillStart => real().nullable()();
  RealColumn get infillEnd => real().nullable()();
  TextColumn get stemName => text().nullable()();
  TextColumn get trackClasses => text().nullable()();

  // ---- inference parameters ----
  BoolColumn get thinking => boolean().nullable()();
  BoolColumn get constrainedDecoding => boolean().nullable()();
  RealColumn get guidanceScale => real().nullable()();
  TextColumn get inferMethod => text().nullable()();
  IntColumn get inferenceSteps => integer().nullable()();
  RealColumn get cfgIntervalStart => real().nullable()();
  RealColumn get cfgIntervalEnd => real().nullable()();
  RealColumn get shift => real().nullable()();
  TextColumn get timeSignature => text().nullable()();
  RealColumn get temperature => real().nullable()();
  RealColumn get cfgScale => real().nullable()();
  RealColumn get topP => real().nullable()();
  RealColumn get repetitionPenalty => real().nullable()();
  RealColumn get audioDuration => real().nullable()();
  IntColumn get batchSize => integer().nullable()();
  BoolColumn get useRandomSeed => boolean().nullable()();
  TextColumn get audioFormat => text().nullable()();

  // ---- workspace ----
  TextColumn get workspaceId => text().nullable()();

  // ---- lyric book ----
  TextColumn get lyricSheetId => text().nullable()();

  // ---- user metadata ----
  TextColumn get title => text().nullable()();
  IntColumn get rating => integer().nullable()();

  // ---- task execution metadata ----
  TextColumn get taskId => text().unique()();
  TextColumn get status => text()();
  TextColumn get result => text().nullable()();
  TextColumn get error => text().nullable()();
  TimestampColumn get completedAt =>
      customType(PgTypes.timestampNoTimezone).nullable()();
}
