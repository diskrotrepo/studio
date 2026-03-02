#!/usr/bin/env bash
# yulan-mini.sh — CLI wrapper for YuLan-Mini text generation via vLLM
# Provides lyrics generation, prompt generation, chat completion, and health checks.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.json"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# ── Dependency checks ────────────────────────────────────────────────────────

check_deps() {
  for cmd in curl jq; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "Error: '$cmd' is required but not installed." >&2
      case "$cmd" in
        jq)
          echo "  macOS:  brew install jq" >&2
          echo "  Linux:  sudo apt-get install jq" >&2
          echo "  Windows: choco install jq" >&2
          ;;
      esac
      exit 1
    fi
  done
}

# ── Config helpers ───────────────────────────────────────────────────────────

load_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: config.json not found at $CONFIG_FILE" >&2
    echo "  Copy config.example.json to config.json and edit it." >&2
    exit 1
  fi
}

cfg_get() {
  jq -r "$1 // empty" "$CONFIG_FILE"
}

cfg_set() {
  local key="$1" value="$2"
  local tmp
  tmp=$(mktemp)
  jq --arg v "$value" "$key = \$v" "$CONFIG_FILE" > "$tmp" && mv "$tmp" "$CONFIG_FILE"
  echo "Set $key = $value"
}

get_api_url() {
  cfg_get '.api_url'
}

get_model() {
  cfg_get '.model'
}

get_max_tokens() {
  local override="$1"
  if [[ -n "$override" ]]; then
    echo "$override"
  else
    cfg_get '.generation.max_tokens'
  fi
}

get_temperature() {
  local override="$1"
  if [[ -n "$override" ]]; then
    echo "$override"
  else
    cfg_get '.generation.temperature'
  fi
}

# ── API calls ────────────────────────────────────────────────────────────────

api_health() {
  local url
  url="$(get_api_url)"
  echo "Checking health at ${url}/health ..."
  local status
  status=$(curl -s -o /dev/null -w "%{http_code}" "${url}/health" 2>/dev/null || echo "000")
  if [[ "$status" == "200" ]]; then
    echo "YuLan-Mini is healthy (HTTP $status)"
  else
    echo "YuLan-Mini health check failed (HTTP $status)" >&2
    echo "  Ensure the yulan service is running: docker compose up yulan" >&2
    return 1
  fi
}

api_models() {
  local url
  url="$(get_api_url)"
  echo "Fetching models from ${url}/v1/models ..."
  curl -s "${url}/v1/models" | jq .
}

api_chat() {
  local system_prompt="$1"
  local user_message="$2"
  local max_tokens="$3"
  local temperature="$4"
  local url model
  url="$(get_api_url)"
  model="$(get_model)"

  local api_key
  api_key="$(cfg_get '.api_key')"

  local auth_header=""
  if [[ -n "$api_key" ]]; then
    auth_header="Authorization: Bearer ${api_key}"
  fi

  local payload
  payload=$(jq -n \
    --arg model "$model" \
    --arg system "$system_prompt" \
    --arg user "$user_message" \
    --argjson max_tokens "$max_tokens" \
    --argjson temperature "$temperature" \
    '{
      model: $model,
      messages: [
        {role: "system", content: $system},
        {role: "user", content: $user}
      ],
      max_tokens: $max_tokens,
      temperature: $temperature
    }')

  local response
  if [[ -n "$auth_header" ]]; then
    response=$(curl -s -X POST "${url}/v1/chat/completions" \
      -H "Content-Type: application/json" \
      -H "$auth_header" \
      -d "$payload")
  else
    response=$(curl -s -X POST "${url}/v1/chat/completions" \
      -H "Content-Type: application/json" \
      -d "$payload")
  fi

  # Check for errors
  local error
  error=$(echo "$response" | jq -r '.error // empty' 2>/dev/null)
  if [[ -n "$error" ]]; then
    echo "API Error: $error" >&2
    echo "$response" | jq . >&2
    return 1
  fi

  # Extract content
  echo "$response" | jq -r '.choices[0].message.content // empty'
}

# ── Commands ─────────────────────────────────────────────────────────────────

cmd_health() {
  api_health
}

cmd_models() {
  api_models
}

cmd_lyrics() {
  local description=""
  local system_prompt=""
  local max_tokens=""
  local temperature=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d|--description) description="$2"; shift 2 ;;
      -s|--system) system_prompt="$2"; shift 2 ;;
      --max-tokens) max_tokens="$2"; shift 2 ;;
      --temperature) temperature="$2"; shift 2 ;;
      *)
        if [[ -z "$description" ]]; then
          description="$1"; shift
        else
          echo "Unknown argument: $1" >&2; exit 1
        fi
        ;;
    esac
  done

  if [[ -z "$description" ]]; then
    echo "Error: description is required" >&2
    echo "Usage: yulan-mini.sh lyrics <description> [--system <prompt>] [--max-tokens N] [--temperature T]" >&2
    exit 1
  fi

  local sys_prompt
  sys_prompt="${system_prompt:-$(cfg_get '.prompts.lyrics')}"
  local tokens
  tokens=$(get_max_tokens "$max_tokens")
  local temp
  temp=$(get_temperature "$temperature")

  echo "Generating lyrics..." >&2
  api_chat "$sys_prompt" "$description" "$tokens" "$temp"
}

cmd_prompt() {
  local description=""
  local system_prompt=""
  local max_tokens=""
  local temperature=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d|--description) description="$2"; shift 2 ;;
      -s|--system) system_prompt="$2"; shift 2 ;;
      --max-tokens) max_tokens="$2"; shift 2 ;;
      --temperature) temperature="$2"; shift 2 ;;
      *)
        if [[ -z "$description" ]]; then
          description="$1"; shift
        else
          echo "Unknown argument: $1" >&2; exit 1
        fi
        ;;
    esac
  done

  if [[ -z "$description" ]]; then
    echo "Error: description is required" >&2
    echo "Usage: yulan-mini.sh prompt <description> [--system <prompt>] [--max-tokens N] [--temperature T]" >&2
    exit 1
  fi

  local sys_prompt
  sys_prompt="${system_prompt:-$(cfg_get '.prompts.audio_style')}"
  local tokens
  tokens=$(get_max_tokens "$max_tokens")
  local temp
  temp=$(get_temperature "$temperature")

  echo "Generating audio prompt..." >&2
  api_chat "$sys_prompt" "$description" "$tokens" "$temp"
}

cmd_chat() {
  local system_prompt=""
  local user_message=""
  local max_tokens=""
  local temperature=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -s|--system) system_prompt="$2"; shift 2 ;;
      -u|--user) user_message="$2"; shift 2 ;;
      --max-tokens) max_tokens="$2"; shift 2 ;;
      --temperature) temperature="$2"; shift 2 ;;
      *)
        if [[ -z "$user_message" ]]; then
          user_message="$1"; shift
        else
          echo "Unknown argument: $1" >&2; exit 1
        fi
        ;;
    esac
  done

  if [[ -z "$user_message" ]]; then
    echo "Error: user message is required" >&2
    echo "Usage: yulan-mini.sh chat <message> [--system <prompt>] [--max-tokens N] [--temperature T]" >&2
    exit 1
  fi

  local sys_prompt
  sys_prompt="${system_prompt:-$(cfg_get '.prompts.default')}"
  local tokens
  tokens=$(get_max_tokens "$max_tokens")
  local temp
  temp=$(get_temperature "$temperature")

  api_chat "$sys_prompt" "$user_message" "$tokens" "$temp"
}

cmd_config() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --get)
        local key="$2"; shift 2
        if [[ "$key" == "api_key" ]]; then
          echo "Error: Use --check-key to verify API key status. Never expose the key." >&2
          exit 1
        fi
        cfg_get ".$key"
        ;;
      --set)
        local key="$2" value="$3"; shift 3
        cfg_set ".$key" "$value"
        ;;
      --check-key)
        shift
        local key
        key="$(cfg_get '.api_key')"
        if [[ -n "$key" ]]; then
          echo "configured"
        else
          echo "empty"
        fi
        ;;
      --list)
        shift
        # Mask api_key in output
        jq '.api_key = (if .api_key != "" then "***" else "" end)' "$CONFIG_FILE"
        ;;
      *)
        echo "Unknown config option: $1" >&2
        echo "Usage: yulan-mini.sh config [--get KEY | --set KEY VALUE | --check-key | --list]" >&2
        exit 1
        ;;
    esac
    return 0
  done
  # No arguments — show config
  jq '.api_key = (if .api_key != "" then "***" else "" end)' "$CONFIG_FILE"
}

# ── Main ─────────────────────────────────────────────────────────────────────

usage() {
  cat <<'USAGE'
yulan-mini.sh — CLI for YuLan-Mini text generation

Commands:
  health                         Check API health
  models                         List available models
  lyrics  <description> [opts]   Generate song lyrics
  prompt  <description> [opts]   Generate audio style prompt
  chat    <message> [opts]       Free-form chat completion
  config  [--get|--set|--list]   View/modify configuration

Generation options:
  -d, --description <text>   Input description (lyrics/prompt)
  -s, --system <text>        Override system prompt
  -u, --user <text>          User message (chat)
  --max-tokens <N>           Max tokens to generate (default: from config)
  --temperature <T>          Sampling temperature (default: from config)

Config options:
  config --list              Show config (masks API key)
  config --get <key>         Get a config value
  config --set <key> <val>   Set a config value
  config --check-key         Check if API key is configured

Examples:
  ./scripts/yulan-mini.sh health
  ./scripts/yulan-mini.sh lyrics "A melancholic ballad about leaving home"
  ./scripts/yulan-mini.sh prompt "Upbeat summer pop with acoustic guitar"
  ./scripts/yulan-mini.sh chat "Explain the circle of fifths" --max-tokens 400
USAGE
}

main() {
  check_deps
  load_config

  if [[ $# -eq 0 ]]; then
    usage
    exit 0
  fi

  local cmd="$1"; shift
  case "$cmd" in
    health)  cmd_health "$@" ;;
    models)  cmd_models "$@" ;;
    lyrics)  cmd_lyrics "$@" ;;
    prompt)  cmd_prompt "$@" ;;
    chat)    cmd_chat "$@" ;;
    config)  cmd_config "$@" ;;
    help|-h|--help) usage ;;
    *)
      echo "Unknown command: $cmd" >&2
      usage
      exit 1
      ;;
  esac
}

main "$@"
