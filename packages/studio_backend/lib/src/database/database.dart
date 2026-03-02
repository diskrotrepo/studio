import 'dart:core';

import 'package:drift/drift.dart';
import 'package:drift_postgres/drift_postgres.dart';

import 'package:studio_backend/src/audio/tables.dart';

import 'package:studio_backend/src/database/postgres.dart';
import 'package:studio_backend/src/database/schema_versions.dart';
import 'package:studio_backend/src/lyric_book/tables.dart';
import 'package:studio_backend/src/peers/tables.dart';
import 'package:studio_backend/src/server_backends/tables.dart';
import 'package:studio_backend/src/settings/tables.dart';
import 'package:studio_backend/src/user/tables.dart';
import 'package:studio_backend/src/workspaces/tables.dart';
import 'package:uuid/uuid.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  User,
  AudioGenerationTask,
  AppSettings,
  ServerBackends,
  PeerConnections,
  Workspaces,
  LyricSheets,
])
class Database extends _$Database {
  Database(super.database);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        // Always use raw SQL — never m.createAll(). The generated versioned
        // schema maps boolean columns incorrectly for PostgreSQL.
        await customStatements('''
          CREATE TABLE IF NOT EXISTS "users" ("id" text NOT NULL, "created_at" timestamp without time zone NOT NULL, "user_id" text NOT NULL, "display_name" text NOT NULL UNIQUE, PRIMARY KEY ("id"));
          CREATE TABLE IF NOT EXISTS "audio_generation_tasks" ("id" text NOT NULL, "created_at" timestamp without time zone NOT NULL, "user_id" text NOT NULL, "model" text NOT NULL, "task_type" text NOT NULL, "prompt" text NULL, "lyrics" text NULL, "negative_prompt" text NULL, "src_audio_path" text NULL, "infill_start" float8 NULL, "infill_end" float8 NULL, "stem_name" text NULL, "track_classes" text NULL, "thinking" boolean NULL, "constrained_decoding" boolean NULL, "guidance_scale" float8 NULL, "infer_method" text NULL, "inference_steps" bigint NULL, "cfg_interval_start" float8 NULL, "cfg_interval_end" float8 NULL, "shift" float8 NULL, "time_signature" text NULL, "temperature" float8 NULL, "cfg_scale" float8 NULL, "top_p" float8 NULL, "repetition_penalty" float8 NULL, "audio_duration" float8 NULL, "batch_size" bigint NULL, "use_random_seed" boolean NULL, "audio_format" text NULL, "workspace_id" text NULL, "lyric_sheet_id" text NULL, "title" text NULL, "rating" bigint NULL, "task_id" text NOT NULL UNIQUE, "status" text NOT NULL, "result" text NULL, "error" text NULL, "completed_at" timestamp without time zone NULL, PRIMARY KEY ("id"));
          CREATE TABLE IF NOT EXISTS "app_settings" ("key" text NOT NULL, "value" text NULL, PRIMARY KEY ("key"));
          CREATE TABLE IF NOT EXISTS "server_backends" ("id" text NOT NULL, "created_at" timestamp without time zone NOT NULL, "name" text NOT NULL, "api_host" text NOT NULL, "secure" boolean NOT NULL DEFAULT false, "is_active" boolean NOT NULL DEFAULT false, PRIMARY KEY ("id"));
          CREATE TABLE IF NOT EXISTS "peer_connections" ("id" text NOT NULL, "public_key" text NOT NULL UNIQUE, "first_seen_at" timestamp without time zone NOT NULL, "last_seen_at" timestamp without time zone NOT NULL, "request_count" bigint NOT NULL DEFAULT 0, "blocked" boolean NOT NULL DEFAULT false, PRIMARY KEY ("id"));
          CREATE TABLE IF NOT EXISTS "workspaces" ("id" text NOT NULL, "created_at" timestamp without time zone NOT NULL, "user_id" text NOT NULL, "name" text NOT NULL, "is_default" boolean NOT NULL DEFAULT false, PRIMARY KEY ("id"));
          CREATE TABLE IF NOT EXISTS "lyric_sheets" ("id" text NOT NULL, "created_at" timestamp without time zone NOT NULL, "user_id" text NOT NULL, "title" text NOT NULL DEFAULT '', "content" text NOT NULL DEFAULT '', PRIMARY KEY ("id"));
          CREATE INDEX ON "users" (user_id);
          CREATE INDEX ON "audio_generation_tasks" (status);
          CREATE INDEX ON "audio_generation_tasks" (workspace_id);
          CREATE INDEX ON "audio_generation_tasks" (lyric_sheet_id);
          CREATE INDEX ON "workspaces" (user_id);
          CREATE INDEX ON "lyric_sheets" (user_id);
        ''');
      },
      onUpgrade: (m, from, to) async {
        await m.runMigrationSteps(
          from: from,
          to: to,
          steps: migrationSteps(
            from1To2: (m, schema) async {
              await customStatement(
                'CREATE TABLE IF NOT EXISTS "peer_connections" ('
                '"id" text NOT NULL, '
                '"public_key" text NOT NULL UNIQUE, '
                '"first_seen_at" timestamp without time zone NOT NULL, '
                '"last_seen_at" timestamp without time zone NOT NULL, '
                '"request_count" bigint NOT NULL DEFAULT 0, '
                '"blocked" boolean NOT NULL DEFAULT false, '
                'PRIMARY KEY ("id")'
                ')',
              );
            },
            from2To3: (m, schema) async {
              await customStatement(
                'CREATE TABLE IF NOT EXISTS "workspaces" ('
                '"id" text NOT NULL, '
                '"created_at" timestamp without time zone NOT NULL, '
                '"user_id" text NOT NULL, '
                '"name" text NOT NULL, '
                '"is_default" boolean NOT NULL DEFAULT false, '
                'PRIMARY KEY ("id")'
                ')',
              );
              await customStatement(
                'ALTER TABLE "audio_generation_tasks" '
                'ADD COLUMN "workspace_id" text NULL',
              );
              await customStatement(
                'CREATE INDEX ON "workspaces" (user_id)',
              );
              await customStatement(
                'CREATE INDEX ON "audio_generation_tasks" (workspace_id)',
              );
            },
            from3To4: (m, schema) async {
              await customStatement(
                'CREATE TABLE IF NOT EXISTS "lyric_sheets" ('
                '"id" text NOT NULL, '
                '"created_at" timestamp without time zone NOT NULL, '
                '"user_id" text NOT NULL, '
                '"title" text NOT NULL DEFAULT \'\', '
                '"content" text NOT NULL DEFAULT \'\', '
                'PRIMARY KEY ("id")'
                ')',
              );
              await customStatement(
                'ALTER TABLE "audio_generation_tasks" '
                'ADD COLUMN "lyric_sheet_id" text NULL',
              );
              await customStatement(
                'CREATE INDEX ON "lyric_sheets" (user_id)',
              );
              await customStatement(
                'CREATE INDEX ON "audio_generation_tasks" (lyric_sheet_id)',
              );
            },
          ),
        );
      },
    );
  }
}
