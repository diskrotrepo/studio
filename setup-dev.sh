#!/usr/bin/env bash
# ==============================================================================
# studio///diskrot — Developer Environment Setup (macOS / Linux)
#
# Installs development prerequisites, configures the environment, fetches
# dependencies, runs code generation, and starts supporting Docker services.
#
# After running this script you can:
#   cd packages/studio_backend && dart run bin/server.dart   (backend)
#   cd packages/studio_ui && flutter run -d chrome           (UI)
#
# Usage:
#   ./setup-dev.sh              Full setup
#   ./setup-dev.sh --skip-docker  Skip Docker install & service startup
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── Helpers ──────────────────────────────────────────────────────────────────

print_banner() {
    echo ""
    echo "============================================================"
    echo "  $1"
    echo "============================================================"
    echo ""
}

print_step()  { echo "[*] $1"; }
print_ok()    { echo "[OK] $1"; }
print_warn()  { echo "[!] $1"; }
print_fail()  { echo "[X] $1"; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

docker_running() { docker info >/dev/null 2>&1; }

wait_for_docker() {
    local timeout="${1:-120}"
    print_step "Waiting for Docker Desktop to be ready..."
    local elapsed=0
    while [ "$elapsed" -lt "$timeout" ]; do
        if docker_running; then
            print_ok "Docker is running."
            return 0
        fi
        sleep 5
        elapsed=$((elapsed + 5))
        echo "  Waiting... (${elapsed}s)"
    done
    return 1
}

# ── Parse arguments ──────────────────────────────────────────────────────────

SKIP_DOCKER=false

for arg in "$@"; do
    case "$arg" in
        --skip-docker) SKIP_DOCKER=true ;;
        -h|--help)
            sed -n '2,/^$/s/^# \?//p' "$0"
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg"
            exit 1
            ;;
    esac
done

# ==============================================================================
print_banner "studio///diskrot — Dev Environment Setup"
# ==============================================================================

# ── Step 1: Xcode CLI Tools / Git ────────────────────────────────────────────

print_banner "Step 1: Git"

if command_exists git; then
    print_ok "Git is installed ($(git --version))."
else
    if [ "$(uname)" = "Darwin" ]; then
        print_step "Installing Xcode Command Line Tools (provides git)..."
        xcode-select --install 2>/dev/null || true
        echo ""
        echo "  A system dialog should appear. Click 'Install' and wait for it to finish."
        echo ""
        read -rp "Press Enter after the installation completes..."
        if command_exists git; then
            print_ok "Git installed."
        else
            print_fail "Git not found after Xcode CLT install."
            exit 1
        fi
    else
        print_fail "Git is not installed. Please install it:"
        echo "  sudo apt install git   (Debian/Ubuntu)"
        echo "  sudo dnf install git   (Fedora)"
        exit 1
    fi
fi

# ── Step 2: Homebrew (macOS only) ────────────────────────────────────────────

if [ "$(uname)" = "Darwin" ]; then
    print_banner "Step 2: Homebrew"

    if command_exists brew; then
        print_ok "Homebrew is installed."
    else
        print_step "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        if [ -f "/opt/homebrew/bin/brew" ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -f "/usr/local/bin/brew" ]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi

        if command_exists brew; then
            print_ok "Homebrew installed."
        else
            print_fail "Homebrew installation failed. Visit https://brew.sh"
            exit 1
        fi
    fi
fi

# ── Step 3: Docker Desktop ──────────────────────────────────────────────────

if [ "$SKIP_DOCKER" = false ]; then
    print_banner "Step 3: Docker Desktop"

    if command_exists docker; then
        print_ok "Docker CLI found."
        if docker_running; then
            print_ok "Docker Desktop is running."
        else
            if [ "$(uname)" = "Darwin" ]; then
                print_step "Starting Docker Desktop..."
                open -a "Docker" 2>/dev/null || true
            fi
            if ! wait_for_docker 120; then
                print_warn "Docker Desktop is not running. Start it manually to use DB services."
            fi
        fi
    else
        if [ "$(uname)" = "Darwin" ] && command_exists brew; then
            print_step "Installing Docker Desktop via Homebrew..."
            brew install --cask docker
            print_ok "Docker Desktop installed."
            print_step "Starting Docker Desktop..."
            open -a "Docker" 2>/dev/null || true
            if ! wait_for_docker 120; then
                print_warn "Docker Desktop is not responding. Start it manually later."
            fi
        else
            print_warn "Docker not found. Install Docker Desktop manually:"
            echo "  https://www.docker.com/products/docker-desktop/"
        fi
    fi
else
    print_step "Skipping Docker (--skip-docker)."
fi

# ── Step 4: Dart SDK ────────────────────────────────────────────────────────

print_banner "Step 4: Dart SDK"

if command_exists dart; then
    dart_version="$(dart --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
    print_ok "Dart SDK found (${dart_version})."
else
    if [ "$(uname)" = "Darwin" ] && command_exists brew; then
        print_step "Installing Dart SDK via Homebrew..."
        brew tap dart-lang/dart
        brew install dart
        if command_exists dart; then
            print_ok "Dart SDK installed."
        else
            print_fail "Dart SDK installation failed."
            exit 1
        fi
    else
        print_fail "Dart SDK not found. Install it:"
        echo "  https://dart.dev/get-dart"
        exit 1
    fi
fi

# ── Step 5: Flutter SDK ─────────────────────────────────────────────────────

print_banner "Step 5: Flutter SDK"

if command_exists flutter; then
    flutter_version="$(flutter --version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
    print_ok "Flutter SDK found (${flutter_version})."
else
    if [ "$(uname)" = "Darwin" ] && command_exists brew; then
        print_step "Installing Flutter SDK via Homebrew..."
        brew install --cask flutter
        if command_exists flutter; then
            print_ok "Flutter SDK installed."
        else
            print_fail "Flutter SDK installation failed."
            exit 1
        fi
    else
        print_fail "Flutter SDK not found. Install it:"
        echo "  https://docs.flutter.dev/get-started/install"
        exit 1
    fi
fi

# ── Step 6: Environment Configuration ───────────────────────────────────────

print_banner "Step 6: Environment Configuration"

if [ -f ".env" ]; then
    print_ok ".env file already exists."
else
    if [ "$(uname)" = "Darwin" ]; then
        if [ -f ".env.mac.sample" ]; then
            cp .env.mac.sample .env
            print_ok ".env created from .env.mac.sample (CPU mode)."
        fi
    else
        if [ -f ".env.windows.sample" ]; then
            cp .env.windows.sample .env
            print_ok ".env created from .env.windows.sample."
        fi
    fi

    if [ ! -f ".env" ]; then
        print_warn "No .env sample found. Create .env manually from the sample files."
    else
        echo ""
        echo "  Edit .env to set your HF_TOKEN (Hugging Face token) if you plan"
        echo "  to run the AI model services."
        echo "  Get a token at: https://huggingface.co/settings/tokens"
        echo ""
    fi
fi

# ── Step 7: Data Directories ────────────────────────────────────────────────

print_banner "Step 7: Data Directories"

mkdir -p data/acestep-checkpoints
mkdir -p data/acestep-output
mkdir -p data/yulan-hf-cache
mkdir -p data/yulan-gguf
print_ok "Data directories ready."

# ── Step 8: Dart/Flutter Dependencies ───────────────────────────────────────

print_banner "Step 8: Dependencies"

print_step "Running dart pub get..."
(cd packages && dart pub get)
print_ok "Dart dependencies installed."

# ── Step 9: Backend Code Generation ─────────────────────────────────────────

print_banner "Step 9: Code Generation"

print_step "Running build_runner for studio_backend..."
(cd packages/studio_backend && dart run build_runner build --delete-conflicting-outputs)
print_ok "Code generation complete."

# ── Step 10: Start Supporting Services ──────────────────────────────────────

if [ "$SKIP_DOCKER" = false ] && docker_running; then
    print_banner "Step 10: Docker Services"

    print_step "Starting postgres and redis..."
    docker compose up -d postgres redis
    print_ok "Database and cache services started."
else
    if [ "$SKIP_DOCKER" = false ]; then
        print_warn "Docker is not running. Skipping service startup."
        echo "  Start Docker Desktop and run: docker compose up -d postgres redis"
    fi
fi

# ── Done ────────────────────────────────────────────────────────────────────

print_banner "Dev Environment Ready!"

echo "  Next steps:"
echo ""
echo "  Backend:  cd packages/studio_backend && dart run bin/server.dart"
echo "  UI:       cd packages/studio_ui && flutter run -d chrome"
echo ""
echo "  Build Docker images from source:"
echo "    ./dev.sh          Backend + UI only"
echo "    ./dev-all.sh      All services including models"
echo ""
echo "  Supporting services:"
echo "    docker compose up -d postgres redis      Start DB + cache"
echo "    docker compose up -d                     Start full stack"
echo "    docker compose down                      Stop all services"
echo ""
