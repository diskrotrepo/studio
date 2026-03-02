---
name: studio-backend-dev
description: Studio backend development guide. Use when building, running, testing, deploying, or debugging the studio_backend Dart server — including Docker, database migrations, code generation, and environment setup.
---

# Studio Backend Development Guide

Dart/Shelf REST API at `packages/studio_backend/`. Built with Drift ORM, Redis caching, and containerized with Docker.

## Tech Stack

- **Language**: Dart (SDK ^3.8.1)
- **Framework**: Shelf + Shelf Router (code-generated routes)
- **Database**: PostgreSQL via Drift ORM
- **Cache**: Redis
- **DI**: GetIt (service locator)
- **Auth**: JWT (dart_jsonwebtoken, jose)
- **Monitoring**: Sentry
- **Build**: build_runner for code generation

## Quick Start

### Local Development

```bash
# From packages/studio_backend/
dart pub get
dart run build_runner build --delete-conflicting-outputs
dart run bin/server.dart
```

### Docker

```bash
# From project root
docker compose up -d --build studio-backend
```

The Dockerfile uses a multi-stage build:
1. `dart:stable` — compiles `bin/server.dart` to native executable
2. `debian:stable-slim` — runtime with `ca-certificates`, `ffmpeg`, `curl`

Runs as non-root user (UID 1001) on port 80.

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `PORT` | No | `80` | Server listen port |
| `REDIS_HOST` | **Yes** | — | Redis hostname |
| `POSTGRES_HOST` | **Yes** | — | PostgreSQL hostname |
| `POSTGRES_DATABASE` | **Yes** | — | PostgreSQL database name |
| `POSTGRES_USER` | **Yes** | — | PostgreSQL username |
| `POSTGRES_PASSWORD` | **Yes** | — | PostgreSQL password |
| `AUDIO_MODELS` | No | `""` | JSON map: `{"ace_step_15": "http://host:8001"}` |
| `AUDIO_API_KEY` | No | — | API key for audio model endpoints |
| `TEXT_MODELS` | No | `""` | JSON map: `{"yulan_mini": "http://host:8003"}` |
| `TEXT_API_KEY` | No | — | API key for text model endpoints |
| `DISABLED_MODELS` | No | `""` | Comma-separated model names to disable |
| `DISKROT_STUDIO_BUCKET` | No | `studio` | Storage bucket name |
| `DISKROT_STORAGE_ROOT` | No | `.` | Local file storage root path |
| `BROWSE_ALLOWED_ROOTS` | No | — | Allowed filesystem browse roots (`;`-separated on Windows, `:`-separated elsewhere) |
| `CORS_ALLOWED_ORIGINS` | No | — | Comma-separated allowed CORS origins |

Services only register if their model endpoints are configured. Missing `AUDIO_MODELS` means no `/v1/audio` routes.

## Code Generation

Routes, DTOs, and database code are generated. After changing any `@Route`, `@JsonSerializable`, or Drift table definitions:

```bash
cd packages/studio_backend
dart run build_runner build --delete-conflicting-outputs
```

Generated files follow the `*.g.dart` naming convention.

## Database

### Schema

7 tables defined across:
- `lib/src/user/tables.dart` — `User` table
- `lib/src/audio/tables.dart` — `AudioGenerationTask` table
- `lib/src/settings/tables.dart` — `AppSettings` table
- `lib/src/server_backends/tables.dart` — `ServerBackends` table
- `lib/src/peers/tables.dart` — `PeerConnections` table
- `lib/src/workspaces/tables.dart` — `Workspaces` table
- `lib/src/lyric_book/tables.dart` — `LyricSheets` table

Database class: `lib/src/database/database.dart` — current `schemaVersion: 4`

### Migrations

```bash
cd packages/studio_backend
sh database_build.sh
```

When adding a new migration:
1. Update table definitions in `tables.dart`
2. Bump `schemaVersion` in `database.dart`
3. Add migration logic in `migration.onUpgrade` using `m.runMigrationSteps` with the generated `migrationSteps()` function from `schema_versions.dart`. Each step is a typed callback like `from1To2`, `from2To3`, etc. — do NOT use `if (from < N)` checks or `wrappedUpgrade`.
4. **CRITICAL: Always use `customStatement()` for ALL schema changes** (creating tables, adding columns, creating indices). Never use `m.createTable()`, `m.addColumn()`, or `m.createAll()`. The generated versioned schema maps boolean columns as `DriftSqlType.int` with SQLite-specific `$customConstraints` (`CHECK (... IN (0, 1))`, `DEFAULT FALSE`), which produces invalid PostgreSQL SQL (e.g. `bigint` column with boolean default). Write raw PostgreSQL DDL instead.
5. Run `sh database_build.sh` to generate schema versions (this generates the `migrationSteps` function and schema classes)
6. Run `dart run build_runner build --delete-conflicting-outputs`

#### Migration Example

```dart
from3To4: (m, schema) async {
  // Always use raw SQL — never m.createTable() or m.addColumn()
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
```

## Project Structure

```
packages/studio_backend/
├── bin/server.dart              # Entry point — mounts routes, starts Shelf server
├── lib/src/
│   ├── dependency_context.dart  # GetIt DI setup — registers all services
│   ├── audio/                   # Audio generation module
│   │   ├── audio_service.dart   # HTTP routes (code-gen'd)
│   │   ├── audio_client.dart    # Multi-model router
│   │   ├── audio_model_client.dart  # Abstract base for model clients
│   │   ├── audio_generation_task_repository.dart  # DB access
│   │   ├── ace_step_15/         # ACE-Step 1.5 model client
│   │   ├── bark/                # Bark model client
│   │   ├── midi/                # MIDI model client
│   │   ├── dto/                 # Request/response DTOs
│   │   └── tables.dart          # Drift table definitions
│   ├── text/                    # Text generation module
│   │   ├── text_service.dart    # HTTP routes
│   │   ├── text_client.dart     # Multi-model router
│   │   ├── text_model_client.dart   # Abstract base
│   │   └── yulan_mini/          # YuLan-Mini model client
│   ├── browse/                  # Filesystem browsing (/v1/browse)
│   ├── crypto/                  # RSA keypair generation
│   ├── lyric_book/              # Lyric sheets module (/v1/lyric-book)
│   ├── training/                # Training proxy — forwards to ACE-Step (/v1/dataset, /v1/training)
│   ├── user/                    # User management
│   ├── settings/                # App settings
│   ├── server_backends/         # Server backend management
│   ├── peers/                   # Peer connection management
│   ├── workspaces/              # Workspace management
│   ├── health/                  # Health check
│   ├── database/                # Drift DB config, PostgreSQL setup
│   ├── cache/                   # Redis cache interface + implementation
│   ├── storage/                 # File storage abstraction (local/cloud)
│   ├── middleware/              # CORS, signature verification, user auto-create, forwarding
│   ├── logger/                  # Console logger + in-memory buffer (/v1/logs)
│   └── utils/                   # Helpers (pagination, JSON, exceptions)
├── test/                        # Test infrastructure
│   ├── fake/                    # Fake implementations (cache, HTTP client)
│   └── helpers/                 # Test setup utilities
├── Dockerfile                   # Multi-stage Docker build
├── pubspec.yaml                 # Dependencies
├── build.yaml                   # Build configuration
└── database_build.sh            # Schema migration script
```

## Architecture Patterns

### Service Layer
Each feature module has a `*Service` class with `@Route` annotations that generate Shelf routers. Services are mounted in `bin/server.dart`.

### Repository Pattern
Data access is abstracted through `*Repository` classes using Drift ORM.

### Model Client Pattern
Audio/text models use an abstract client base class. Concrete implementations (e.g., `AceStep15Client`) act as anticorruption layers, mapping standardized diskrot API fields to model-specific fields.

### Async Task Processing
Audio generation is fire-and-forget:
1. `POST /generate` creates a task, caches `processing` status, returns `task_id`
2. Generation runs asynchronously via `unawaited()`
3. Client polls `GET /tasks/<taskId>` for status
4. Result persisted to DB + cache (1-hour TTL)

### Dependency Injection
All wiring happens in `lib/src/dependency_context.dart`. Services conditionally register based on env vars.

## Testing

```bash
cd packages/studio_backend
dart test
```

Test infrastructure in `test/`:
- `fake/fake_cache.dart` — in-memory Cache implementation
- `helpers/test_setup.dart` — test initialization

Uses `mocktail` for mocking.

## Adding a New Service

1. Create `lib/src/<feature>/` directory with service, repository, tables, DTOs
2. Add `@Route` annotations to service class
3. Register in `dependency_context.dart`
4. Mount router in `server.dart`: `rootRouter.mount('/v1/<feature>', di.get<FeatureService>().router.call)`
5. Run `dart run build_runner build --delete-conflicting-outputs`

## Adding a New Table

1. Define table class in `lib/src/<feature>/tables.dart`
2. Add to `@DriftDatabase(tables: [...])` in `database.dart`
3. Bump `schemaVersion` and add migration
4. Run `sh database_build.sh`
5. Run `dart run build_runner build --delete-conflicting-outputs`
