---
name: studio-backend-models
description: Guide for adding new AI model clients to studio_backend. Use when integrating a new audio or text model, implementing a model client, or understanding the model client architecture.
allowed-tools: Read, Glob, Grep
---

# Adding Model Clients to Studio

Guide for integrating new audio or text AI models. Covers both the backend anticorruption layer (`packages/studio_backend/`) and the Flutter UI (`packages/studio_ui/`).

## Architecture Overview

```
UI (CreatePage) ←→ ApiClient ←→ AudioService ←→ AudioClient (router) ←→ ModelClient (anticorruption) ←→ External API
                                       ↑
                              GET /<model>/capabilities
```

- **Service** (`AudioService`) — HTTP routes, validation, task orchestration
- **Client** (`AudioClient`) — routes requests to the correct model client by name
- **ModelClient** (`AudioModelClient`) — abstract base class; each model gets its own subclass
- **Capabilities** — each model client declares what task types, parameters, and features it supports; the UI uses this to show/hide controls

## Adding a New Audio Model — Full Checklist

### 1. Create the Client

Create `lib/src/audio/<model_name>/<model_name>_client.dart`:

```dart
import 'package:studio_backend/src/audio/audio_model_client.dart';

class MyModelClient extends AudioModelClient {
  MyModelClient({required String baseUrl, super.apiKey, super.client})
      : super(baseUrl: baseUrl);

  // ---- Capabilities ----

  @override
  Map<String, dynamic> get capabilities => {
    'task_types': ['generate', 'cover'],  // only the tasks this model supports
    'parameters': [
      'prompt',           // always include if model accepts text input
      'audio_duration',   // include each standardized param this model uses
      'temperature',
    ],
    'features': {
      'lora': false,            // true only if model implements LoRA methods
      'lyrics': false,          // true only if model accepts lyrics input
      'negative_prompt': false, // true only if model accepts negative prompts
    },
  };

  // ---- Submit ----

  @override
  Future<Map<String, dynamic>> submit(
    String taskType,
    Map<String, dynamic> payload, {
    required String userId,
  }) async {
    // Validate task type
    final endpoint = _taskTypeEndpoints[taskType];
    if (endpoint == null) {
      throw AudioModelException(
        400,
        'MyModel does not support task type "$taskType". '
        'Supported: ${_taskTypeEndpoints.keys.join(', ')}',
      );
    }

    final mapped = _mapPayload(payload);
    final response = await post(endpoint, mapped);

    // Return in standard format: { "results": [{ "file": "url" }] }
    return response;
  }

  // ---- Field Mapping ----

  static const _taskTypeEndpoints = {
    'generate': '/api/generate',
    'cover': '/api/cover',
  };

  static const _fieldNameMap = {
    'prompt': 'text',              // diskrot name → model-specific name
    'audio_duration': 'length',
  };

  Map<String, dynamic> _mapPayload(Map<String, dynamic> payload) {
    final mapped = <String, dynamic>{};
    for (final entry in payload.entries) {
      if (entry.value == null) continue;
      final key = _fieldNameMap[entry.key] ?? entry.key;
      mapped[key] = entry.value;
    }
    return mapped;
  }
}
```

### 2. Define Capabilities

The `capabilities` getter is **required** by `AudioModelClient`. It returns a map with three keys:

| Key | Type | Description |
|-----|------|-------------|
| `task_types` | `List<String>` | Supported task types from: `generate`, `generate_long`, `infill`, `cover`, `extract`, `add_stem`, `replace_track`, `extend` |
| `parameters` | `List<String>` | Supported parameters using **standardized diskrot field names** (not model-specific names) |
| `features` | `Map<String, bool>` | High-level feature flags that control UI section visibility |

**Current feature flags:**

| Feature | Controls |
|---------|----------|
| `lora` | LoRA management section in UI |
| `lyrics` | Lyrics text field in generate/infill/cover/extend forms |
| `negative_prompt` | "Avoid" text field in advanced section |

**Parameter → UI control mapping:**

| Parameter | UI Control |
|-----------|-----------|
| `temperature` | Creativity slider |
| `guidance_scale` | Prompt Strength slider |
| `inference_steps` | Quality slider |
| `audio_duration` | Duration slider |
| `batch_size` | Variations slider |
| `cfg_scale` | CFG Scale slider |
| `top_p` | Top P slider |
| `repetition_penalty` | Repetition Penalty slider |
| `shift` | Shift slider |
| `cfg_interval_start` | CFG Interval Start slider |
| `cfg_interval_end` | CFG Interval End slider |
| `thinking` | Thinking toggle |
| `constrained_decoding` | Constrained Decoding toggle |
| `use_random_seed` | Random Seed toggle + seed field |

The UI hides any control whose parameter is not in the model's `parameters` list. If capabilities haven't loaded yet (server unreachable), all controls are shown as a fallback.

### 3. Register in Dependency Context

Edit [dependency_context.dart](packages/studio_backend/lib/src/dependency_context.dart):

```dart
import 'package:studio_backend/src/audio/<model_name>/<model_name>_client.dart';

// Inside dependencySetup(), in the audioModels block:
final modelClients = <String, AudioModelClient>{
  // existing models...
  if (audioModels.containsKey('my_model'))
    'my_model': MyModelClient(
      baseUrl: audioModels['my_model']!,
      apiKey: audioApiKey,
    ),
};
```

### 4. Add to UI Model Dropdown

Edit [create_page.dart](packages/studio_ui/lib/pages/create_page.dart) — add a `DropdownMenuItem` in the model selector:

```dart
DropdownMenuItem(
  value: 'my_model',
  child: Text('My Model'),
),
```

No other UI changes needed — the capabilities system automatically shows/hides task types, parameters, and features based on the model's `capabilities` getter.

### 5. Configure Environment

```bash
AUDIO_MODELS='{"ace_step_15":"http://localhost:8001","my_model":"http://localhost:8005"}'
```

### 6. No Route Changes Needed

The `AudioService` is model-agnostic. The capabilities endpoint `GET /<model>/capabilities` works automatically for any registered model. Clients specify the model in their request body:

```json
{ "model": "my_model", "task_type": "generate", "prompt": "..." }
```

## Capabilities API

`GET /v1/audio/<model>/capabilities`

Response:
```json
{
  "data": {
    "model": "my_model",
    "task_types": ["generate", "cover"],
    "parameters": ["prompt", "audio_duration", "temperature"],
    "features": { "lora": false, "lyrics": false, "negative_prompt": false }
  }
}
```

The UI fetches this on model selection change and uses it to:
1. Filter the task type dropdown (always-available types `upload`, `crop`, `fade` are shown regardless)
2. Show/hide advanced parameter sliders and toggles
3. Show/hide LoRA section
4. Show/hide lyrics fields in task-specific forms
5. Filter the submit payload to only include supported parameters

## Existing Models — Capability Matrix

| Capability | ACE-Step 1.5 | MIDI | Bark |
|-----------|:---:|:---:|:---:|
| **Task: generate** | yes | yes | yes |
| **Task: generate_long** | - | - | yes |
| **Task: infill** | yes | - | - |
| **Task: cover** | yes | yes | - |
| **Task: extract** | yes | - | - |
| **Task: add_stem** | yes | yes | - |
| **Task: replace_track** | - | yes | - |
| **Task: extend** | yes | yes | - |
| **Feature: lora** | yes | - | - |
| **Feature: lyrics** | yes | - | - |
| **Feature: negative_prompt** | yes | - | - |
| **Params** | all 20 | 9 (prompt, audio_duration, bpm, temperature, top_k, top_p, repetition_penalty, humanize, seed) | prompt, temperature |

## Adding a New Text Model

### 1. Create the Client

Create `lib/src/text/<model_name>/<model_name>_client.dart`:

```dart
import 'package:studio_backend/src/text/text_model_client.dart';

class MyTextModelClient extends TextModelClient {
  MyTextModelClient({required super.baseUrl, super.apiKey});

  @override
  Future<String> generateLyrics(String description, {String? systemPrompt}) async {
    // Call your model's API and return lyrics text
  }

  @override
  Future<String> generatePrompt(String description, {String? systemPrompt}) async {
    // Call your model's API and return prompt text
  }
}
```

### 2. Register and Configure

Same pattern as audio: add to `dependency_context.dart` and set `TEXT_MODELS` env var.

## AudioModelClient Base Class

Located at [audio_model_client.dart](packages/studio_backend/lib/src/audio/audio_model_client.dart).

**Provided methods** (inherited by all audio model clients):

| Method | Description |
|--------|-------------|
| `post(path, body)` | POST JSON to model endpoint with auth headers |
| `getRequest(path)` | GET from model endpoint with auth headers |
| `healthCheck()` | GET `/health` on model endpoint, returns bool |

**Required overrides:**

| Member | Description |
|--------|-------------|
| `capabilities` | Getter returning supported task types, parameters, and features |
| `submit(taskType, payload, userId)` | Map fields and submit generation request |

**Optional LoRA overrides** (default throws "not supported"):

| Method | Description |
|--------|-------------|
| `getLoraList()` | List available LoRA adapters |
| `getLoraStatus()` | Current LoRA status |
| `loadLora(path, adapterName?)` | Load a LoRA adapter |
| `unloadLora()` | Unload current LoRA |
| `toggleLora(bool)` | Enable/disable LoRA |
| `setLoraScale(scale, adapterName?)` | Set LoRA scale factor |

## UI Capabilities Integration

Located at [create_page.dart](packages/studio_ui/lib/pages/create_page.dart).

The `CreatePage` fetches capabilities via `ApiClient.getModelCapabilities(model)` on every model change. The `ModelCapabilities` class (at [model_capabilities.dart](packages/studio_ui/lib/models/model_capabilities.dart)) provides:

- `supportsTaskType(String)` — used to filter task type dropdown
- `supportsParameter(String)` — used to show/hide advanced sliders/toggles and filter submit payload
- `hasFeature(String)` — used to show/hide LoRA section, lyrics fields, negative prompt field

Helper methods in `CreatePage`:
- `_availableTaskTypes` — computed getter combining model task types + always-available types
- `_supportsParam(String)` — delegates to capabilities with `true` fallback
- `_hasFeature(String)` — delegates to capabilities with `true` fallback

Always-available task types (client-side, not model-dependent): `upload`, `crop`, `fade`

## ACE-Step 1.5 Client Reference

[ace_step_15_client.dart](packages/studio_backend/lib/src/audio/ace_step_15/ace_step_15_client.dart) — full-featured reference implementation.

**Key patterns:**

- **Task type mapping**: diskrot `generate` → ace_step `text2music`, `infill` → `repaint`, `add_stem` → `lego`
- **Field name mapping**: `infill_start` → `repainting_start`, `negative_prompt` → `lm_negative_prompt`, etc.
- **Async polling**: Submits via `/release_task`, polls `/query_result` every 3s (max 200 attempts / ~10 min)
- **URL resolution**: Makes relative file URLs absolute using model base URL
- **Full LoRA support**: All 6 LoRA operations implemented
- **Full capabilities**: All task types, all parameters, all features enabled

## Standardized diskrot Field Names

These are the field names used in the `AudioGenerateRequest` DTO. Your model client maps them to model-specific names via `_fieldNameMap`.

**Task types**: `generate`, `generate_long`, `infill`, `cover`, `extract`, `add_stem`, `replace_track`, `extend`

**Content fields**: `prompt`, `lyrics`, `negative_prompt`

**Source audio**: `src_audio_path`, `infill_start`, `infill_end`, `stem_name`, `track_classes`, `repainting_start`, `repainting_end`

**Inference params**: `thinking`, `constrained_decoding`, `guidance_scale`, `infer_method`, `inference_steps`, `cfg_interval_start`, `cfg_interval_end`, `shift`, `time_signature`, `temperature`, `cfg_scale`, `top_p`, `top_k`, `repetition_penalty`, `audio_duration`, `batch_size`, `bpm`, `humanize`, `seed`, `use_random_seed`, `audio_format`

## Key Source Files

| File | Description |
|------|-------------|
| [audio_model_client.dart](packages/studio_backend/lib/src/audio/audio_model_client.dart) | Abstract audio model base class (capabilities + submit) |
| [audio_client.dart](packages/studio_backend/lib/src/audio/audio_client.dart) | Audio model router (getCapabilities, getAllCapabilities) |
| [audio_service.dart](packages/studio_backend/lib/src/audio/audio_service.dart) | HTTP routes including `/<model>/capabilities` |
| [ace_step_15_client.dart](packages/studio_backend/lib/src/audio/ace_step_15/ace_step_15_client.dart) | ACE-Step reference implementation |
| [midi_client.dart](packages/studio_backend/lib/src/audio/midi/midi_client.dart) | MIDI client (limited capabilities) |
| [bark_client.dart](packages/studio_backend/lib/src/audio/bark/bark_client.dart) | Bark client (minimal capabilities) |
| [audio_generate_request.dart](packages/studio_backend/lib/src/audio/dto/audio_generate_request.dart) | Request DTO with validation |
| [dependency_context.dart](packages/studio_backend/lib/src/dependency_context.dart) | Service registration |
| [model_capabilities.dart](packages/studio_ui/lib/models/model_capabilities.dart) | UI capabilities model class |
| [create_page.dart](packages/studio_ui/lib/pages/create_page.dart) | UI integration (filtering, show/hide) |
| [api_client.dart](packages/studio_ui/lib/services/api_client.dart) | UI HTTP client (getModelCapabilities) |
| [text_model_client.dart](packages/studio_backend/lib/src/text/text_model_client.dart) | Abstract text model base class |
| [yulan_mini_client.dart](packages/studio_backend/lib/src/text/yulan_mini/yulan_mini_client.dart) | YuLan-Mini reference implementation |
| [text_client.dart](packages/studio_backend/lib/src/text/text_client.dart) | Text model router |
