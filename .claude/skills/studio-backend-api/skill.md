---
name: studio-backend-api
description: Studio backend REST API reference. Use when working with API endpoints, request/response formats, authentication, task types, or debugging API issues in studio_backend.
---

# Studio Backend API Reference

Dart/Shelf REST API serving the diskrot studio application. All source code lives in `packages/studio_backend/`.

## Base URL

Default port: `80` (configurable via `PORT` env var). All routes are prefixed with `/v1`.

## API Endpoints

### Health — `/v1/health`

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/status` | No | Server health check |

### Users — `/v1/users`

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/me` | No | Get server's external user ID |
| GET | `/<userId>` | Admin | Get user info by userId |

### Settings — `/v1/settings`

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/` | No | Get all app settings |
| PUT | `/` | No | Update settings (whitelist: `lyrics_system_prompt`, `prompt_system_prompt`, `allow_peer_connections`, `visualizer_type`; supports namespaced variants like `key:model_name`) |

### Audio Generation — `/v1/audio`

**Health & Metadata:**

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/health` | No | Check all audio model endpoint health |
| GET | `/<model>/defaults` | No | Get model default parameters |
| GET | `/<model>/capabilities` | No | Get model capabilities |

**Songs (authenticated):**

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/songs` | Yes | List user's songs (cursor paginated: `?cursor=&limit=&rating=&sort=newest\|oldest&workspace_id=&lyrics_search=`) |
| GET | `/songs/<songId>` | Yes | Get specific song details (includes `parameters` object) |
| GET | `/songs/<songId>/download` | Yes | Download generated audio file |
| PATCH | `/songs/<songId>` | Yes | Update song (`{ title?, rating?, workspace_id?, lyric_sheet_id? }` — at least one required) |
| DELETE | `/songs/<songId>` | Yes | Delete song and clean up storage |
| POST | `/songs/batch-delete` | Yes | Batch delete songs (`{ task_ids: [...] }`, max 100) |

**Generation:**

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/generate` | No | Submit audio generation task, returns `{ task_id }` |
| GET | `/tasks/<taskId>` | No | Poll task status (`processing`, `complete`, `failed`) |

**File Upload:**

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/upload` | Yes | Initiate upload session, returns upload ID and URL |
| PUT | `/upload/finalize` | Yes | Finalize upload with binary data (header: `Diskrot-File-Id`) |

**LoRA Management:**

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/lora/list` | No | List available LoRA adapters |
| GET | `/lora/status` | No | Get current LoRA status |
| POST | `/lora/load` | No | Load LoRA adapter (`{ lora_path, adapter_name? }`) |
| POST | `/lora/unload` | No | Unload current LoRA |
| POST | `/lora/toggle` | No | Enable/disable LoRA (`{ use_lora: bool }`) |
| POST | `/lora/scale` | No | Set LoRA scale (`{ scale: double, adapter_name? }`) |

### Text Generation — `/v1/text`

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/lyrics` | No | Generate lyrics (`{ model, description, audio_model? }`) |
| POST | `/prompt` | No | Generate audio prompt (`{ model, description, audio_model? }`) |

### Server Backends — `/v1/server-backends`

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/` | No | List all configured remote backends |
| POST | `/` | No | Create backend (`{ name, api_host, secure? }`) |
| PUT | `/<id>` | No | Update backend (`{ name?, api_host?, secure? }`) |
| DELETE | `/<id>` | No | Delete backend (deactivates first if active) |
| PUT | `/<id>/activate` | No | Activate remote backend for request forwarding |

### Peers — `/v1/peers`

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/` | No | List all connected peers |
| PUT | `/<id>/block` | No | Block a peer |
| PUT | `/<id>/unblock` | No | Unblock a peer |

### Workspaces — `/v1/workspaces`

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/` | No | List workspaces (lazy-creates default, backfills unassigned songs) |
| POST | `/` | No | Create workspace (`{ name }`, max 200 chars) |
| PUT | `/<id>` | No | Rename workspace (`{ name }`) |
| DELETE | `/<id>` | No | Delete workspace (songs reassigned to default; cannot delete default) |

### Lyric Book — `/v1/lyric-book`

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/` | No | List all lyric sheets |
| POST | `/` | No | Create lyric sheet (`{ title?, content? }`) |
| GET | `/search` | No | Search lyric sheets (`?q=`) |
| GET | `/<id>` | No | Get lyric sheet with linked songs |
| PATCH | `/<id>` | No | Update lyric sheet (`{ title?, content? }`) |
| DELETE | `/<id>` | No | Delete lyric sheet (unlinks songs) |

### Logs — `/v1/logs`

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/` | No | Get buffered log entries |

### Browse — `/v1/browse`

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/` | No | Browse filesystem (`{ path, file_extensions? }`); restricted to allowed roots |

### Training Proxy — `/v1/dataset/*` & `/v1/training/*`

All paths are transparently forwarded to the ACE-Step Python server. Only mounted when `ace_step_15` model is configured. The proxy translates JSON `code` fields into HTTP status codes.

## Audio Generation Request

`POST /v1/audio/generate` — `Content-Type: application/json`

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `model` | string | Model name (e.g., `ace_step_15`) |
| `task_type` | string | One of: `generate`, `generate_long`, `infill`, `cover`, `extract`, `add_stem`, `extend` |

### Task Type Requirements

| Task Type | Required Fields |
|-----------|----------------|
| `generate` | `prompt` |
| `generate_long` | `prompt` |
| `infill` | `src_audio_path`, `infill_start`, `infill_end` |
| `cover` | `src_audio_path` |
| `extract` | `src_audio_path`, `stem_name` |
| `add_stem` | `src_audio_path`, `stem_name` |
| `extend` | `src_audio_path` |

### Valid Stem Names

`vocals`, `drums`, `bass`, `guitar`, `keyboard`, `strings`, `synth`, `percussion`, `brass`, `woodwinds`, `fx`, `backing_vocals`

### Optional Fields

| Field | Type | Description |
|-------|------|-------------|
| `prompt` | string | Text description / caption |
| `lyrics` | string | Song lyrics |
| `negative_prompt` | string | Negative prompt for generation |
| `src_audio_path` | string | Path to source audio (bucket/object from upload) |
| `infill_start` | double | Start time for infill (seconds) |
| `infill_end` | double | End time for infill (seconds) |
| `repainting_start` | double | Start time for repainting |
| `repainting_end` | double | End time for repainting |
| `stem_name` | string | Target stem for extract/add_stem |
| `track_classes` | list | Track classification data |
| `thinking` | bool | Enable LM thinking mode |
| `constrained_decoding` | bool | Enable constrained decoding |
| `guidance_scale` | double | Guidance scale |
| `temperature` | double | LM temperature |
| `cfg_scale` | double | LM CFG scale |
| `top_p` | double | LM top-p sampling |
| `repetition_penalty` | double | LM repetition penalty |
| `infer_method` | string | Inference method |
| `inference_steps` | int | Number of inference steps |
| `cfg_interval_start` | double | CFG interval start |
| `cfg_interval_end` | double | CFG interval end |
| `shift` | double | Shift parameter |
| `time_signature` | string | Time signature |
| `audio_duration` | double | Duration in seconds |
| `batch_size` | int | Number of outputs |
| `use_random_seed` | bool | Use random seed |
| `audio_format` | string | Output format (mp3/wav/flac) |

## Task Status Response

`GET /v1/audio/tasks/<taskId>`

```json
{
  "task_id": "uuid",
  "status": "processing|complete|failed",
  "task_type": "generate",
  "result": { "results": [{ "file": "http://..." }] },
  "error": "error message if failed"
}
```

Task statuses are cached in Redis with a 1-hour TTL (`audio_task:<taskId>`).

## Upload Flow

1. `POST /v1/audio/upload` with `{ filename, contentType, size }` — returns `{ id, objectName, uploadUrl }`
2. `PUT /v1/audio/upload/finalize` with binary body and `Diskrot-File-Id` header — stores the file
3. Use the returned `bucket` + `object` as `src_audio_path` in generation requests

## Authentication

- **User ID**: `Diskrot-User-Id` header (1-100 alphanumeric chars, defaults to `'1'`). Auto-created via `userAutoCreateMiddleware`.
- **Admin**: Requests without `X-Signature` / `X-Public-Key` headers are treated as admin (local).
- **Peer auth**: RSA-2048 signatures via `X-Signature`, `X-Public-Key`, `X-Timestamp` headers. Message: `"$METHOD\n$PATH\n$TIMESTAMP\n$BODY"`. Timestamp must be within 300s.

## Key Source Files

All paths relative to `packages/studio_backend/lib/src/`.

| File | Description |
|------|-------------|
| `audio/audio_service.dart` | Audio API routes and task orchestration |
| `audio/dto/audio_generate_request.dart` | Request DTO with validation |
| `text/text_service.dart` | Text generation routes |
| `user/user_service.dart` | User management routes |
| `settings/settings_service.dart` | Settings routes |
| `health/health_service.dart` | Health check route |
| `workspaces/workspace_service.dart` | Workspace CRUD routes |
| `lyric_book/lyric_book_service.dart` | Lyric sheet CRUD routes |
| `server_backends/server_backend_service.dart` | Remote backend management routes |
| `peers/peer_service.dart` | Peer connection management routes |
| `browse/browse_service.dart` | Filesystem browsing route |
| `logger/log_service.dart` | Log retrieval route |
| `training/training_proxy_service.dart` | Training proxy to ACE-Step Python server |
| `middleware/signature_middleware.dart` | RSA peer signature verification |
| `middleware/forwarding_middleware.dart` | Request forwarding to active remote backend |
| `middleware/user_middleware.dart` | Auto-create user from Diskrot-User-Id |
| `utils/shelf_helper.dart` | Response helpers (jsonOk, jsonErr) |
| `utils/cursor_pagination.dart` | Cursor-based pagination utilities |
