---
name: yulan-mini
description: Use YuLan-Mini LLM for text generation — song lyrics, audio style prompts, and general chat completions. YuLan-Mini is a 2.4B parameter model served via llama.cpp (CPU or CUDA). Use this skill when users want to generate lyrics, create audio descriptions, or need text generation from the local LLM.
allowed-tools: Read, Write, Bash
---

# YuLan-Mini Text Generation Skill

Use YuLan-Mini (2.4B) via llama.cpp for text generation. **Always use `scripts/yulan-mini.sh` script** — do NOT call API endpoints directly.

## Quick Start

```bash
# 1. cd to this skill's directory
cd {project_root}/{.claude or .codex}/skills/yulan-mini/

# 2. Check API service health
./scripts/yulan-mini.sh health

# 3. Generate song lyrics
./scripts/yulan-mini.sh lyrics "A melancholic ballad about leaving home"

# 4. Generate an audio style prompt for ACE-Step
./scripts/yulan-mini.sh prompt "Upbeat summer pop with acoustic guitar"

# 5. Free-form chat
./scripts/yulan-mini.sh chat "Explain the circle of fifths"
```

## Capabilities

YuLan-Mini serves three text generation functions in the studio:

| Command | Purpose | Use Case |
|---------|---------|----------|
| `lyrics` | Generate song lyrics from a description | Songwriting workflow before ACE-Step generation |
| `prompt` | Generate audio style/caption descriptions | Create captions for ACE-Step music generation |
| `chat` | General-purpose chat completion | Any text generation task |

### Integration with ACE-Step Workflow

YuLan-Mini is the text brain behind the music generation pipeline:

1. User describes a song idea
2. **YuLan-Mini generates lyrics** (`lyrics` command)
3. **YuLan-Mini generates an audio caption** (`prompt` command)
4. Both are fed to ACE-Step via the **acestep** skill for music generation

## Script Commands

```bash
# need to cd to this skill's directory first
cd {project_root}/{.claude or .codex}/skills/yulan-mini/

# Generate lyrics from a description
./scripts/yulan-mini.sh lyrics "A punk rock anthem about fighting conformity"
./scripts/yulan-mini.sh lyrics -d "Jazz ballad about rainy nights" --max-tokens 800

# Generate audio style prompt
./scripts/yulan-mini.sh prompt "Dark electronic song with heavy bass"
./scripts/yulan-mini.sh prompt -d "Acoustic folk love song" --temperature 0.7

# Free-form chat completion
./scripts/yulan-mini.sh chat "What chord progression works for a sad ballad?"
./scripts/yulan-mini.sh chat -u "Suggest a song structure for a 3-minute pop song" --max-tokens 400

# Override the system prompt
./scripts/yulan-mini.sh lyrics "Spring morning" --system "You are a haiku poet. Write lyrics as a series of haiku."

# Health and info
./scripts/yulan-mini.sh health
./scripts/yulan-mini.sh models
```

### Generation Options

| Option | Default | Description |
|--------|---------|-------------|
| `-d`, `--description` | — | Input text (lyrics/prompt commands) |
| `-u`, `--user` | — | User message (chat command) |
| `-s`, `--system` | per-command default | Override system prompt |
| `--max-tokens` | `600` | Max tokens to generate |
| `--temperature` | `0.85` | Sampling temperature (0.0–2.0) |

## Configuration

**Important**: Configuration follows this priority (high to low):

1. **Command line arguments** > **config.json defaults**
2. User-specified parameters **temporarily override** defaults but **do not modify** config.json
3. Only `config --set` command **permanently modifies** config.json

### Default Config File (`scripts/config.json`)

```json
{
  "api_url": "http://127.0.0.1:8003",
  "api_key": "",
  "model": "diskrot/YuLan-Mini-diskrot",
  "generation": {
    "max_tokens": 600,
    "temperature": 0.85
  },
  "prompts": {
    "default": "You are YuLan-Mini, a helpful assistant...",
    "lyrics": "You are a creative lyricist...",
    "audio_style": "You are a music producer..."
  }
}
```

| Option | Default | Description |
|--------|---------|-------------|
| `api_url` | `http://127.0.0.1:8003` | llama-server address |
| `api_key` | `""` | API authentication key (optional for local) |
| `model` | `diskrot/YuLan-Mini-diskrot` | Model identifier |
| `generation.max_tokens` | `600` | Default max tokens |
| `generation.temperature` | `0.85` | Default sampling temperature |
| `prompts.lyrics` | *(lyrics system prompt)* | System prompt for lyrics generation |
| `prompts.audio_style` | *(audio style prompt)* | System prompt for audio prompt generation |
| `prompts.default` | *(general prompt)* | System prompt for chat completions |

### Config Commands

```bash
# View config (API key masked)
./scripts/yulan-mini.sh config --list

# Get a specific value
./scripts/yulan-mini.sh config --get api_url
./scripts/yulan-mini.sh config --get generation.max_tokens

# Set a value
./scripts/yulan-mini.sh config --set api_url "http://remote-server:8003"
./scripts/yulan-mini.sh config --set generation.max_tokens 1024

# Check if API key is configured (safe — never exposes key)
./scripts/yulan-mini.sh config --check-key
```

**API Key Handling**: When checking whether an API key is configured, use `config --check-key` which only reports `configured` or `empty` without printing the actual key. **NEVER use `config --get api_key`** or read `config.json` directly — these would expose the user's API key. The `config --list` command is safe — it automatically masks API keys as `***` in output.

## Prerequisites — YuLan-Mini Service

**IMPORTANT**: This skill requires the YuLan-Mini llama-server service to be running.

### Required Dependencies

The `scripts/yulan-mini.sh` script requires: **curl** and **jq**.

### Before First Use

**You MUST check the API health before proceeding.** Run:

```bash
cd "{project_root}/{.claude or .codex}/skills/yulan-mini/" && bash ./scripts/yulan-mini.sh health
```

#### If health check succeeds

Proceed with text generation.

#### If health check fails

Start the service with `docker compose up yulan -d` and wait for it to become healthy. First startup downloads the GGUF model (~2.5 GB) and may take several minutes. Subsequent starts are fast (model is cached to the `data/yulan-gguf` volume).

The service works on all platforms:
- **Mac (Apple Silicon)**: CPU mode via `YULAN_VARIANT=cpu` (default)
- **NVIDIA GPU**: CUDA mode via `YULAN_VARIANT=cuda` + GPU overlay

### Model Details

| Property | Value |
|----------|-------|
| **Model** | `diskrot/YuLan-Mini-GGUF-diskrot` (GGUF quantized YuLan-Mini) |
| **Parameters** | 2.4B |
| **Context Length** | 4096 tokens |
| **Format** | GGUF Q8_0 |
| **Serving** | llama.cpp (llama-server) — OpenAI-compatible API |
| **Port** | 8003 |
| **GPU Required** | No (CPU default, optional CUDA acceleration) |

### API Compatibility

YuLan-Mini is served via llama-server and exposes an OpenAI-compatible API:

| Endpoint | Description |
|----------|-------------|
| `GET /health` | Health check |
| `GET /v1/models` | List available models |
| `POST /v1/chat/completions` | Chat completion (used by all commands) |

## Tips

- **Lyrics quality**: Be specific in your description. "A melancholic piano ballad about leaving your childhood home in autumn" produces better results than "a sad song."
- **Temperature tuning**: Lower temperature (0.5–0.7) for more focused/predictable output, higher (0.8–1.0) for more creative/varied output.
- **Max tokens**: For full song lyrics, consider increasing to 800–1024. The default 600 works well for shorter pieces.
- **Custom system prompts**: Override the system prompt with `--system` for specialized tasks like writing in a specific language, style, or format.
