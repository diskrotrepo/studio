#!/usr/bin/env bash
# ==============================================================================
# studio///diskrot -- macOS Installer
#
# Installs all prerequisites for studio///diskrot:
#   - Xcode Command Line Tools (for git)
#   - Homebrew
#   - Docker Desktop
#   - Project configuration (.env)
#   - Docker image pull and stack launch
#
# Usage:
#   ./installer/install.sh              # auto-detect install vs update
#   ./installer/install.sh --update     # force update mode
#   ./installer/install.sh --uninstall  # stop and optionally remove data
#
# One-liner install (paste into Terminal):
#   curl -fsSL https://raw.githubusercontent.com/diskrotrepo/studio/stable/installer/install.sh -o /tmp/diskrot-install.sh && bash /tmp/diskrot-install.sh
# ==============================================================================

set -euo pipefail

# --- Constants ----------------------------------------------------------------
STUDIO_REPO="https://github.com/diskrotrepo/studio.git"
DOCKER_DMG_URL_ARM="https://desktop.docker.com/mac/main/arm64/Docker.dmg"
DOCKER_DMG_URL_X86="https://desktop.docker.com/mac/main/amd64/Docker.dmg"
STUDIO_COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"

# --- Helpers ------------------------------------------------------------------

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

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

docker_running() {
    docker info >/dev/null 2>&1
}

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

docker_compose_pull_with_retry() {
    local max_attempts="${1:-3}"
    local attempt=1
    while [ "$attempt" -le "$max_attempts" ]; do
        if [ "$attempt" -gt 1 ]; then
            print_warn "Pull attempt $((attempt - 1)) failed. Retrying ($attempt/$max_attempts)..."
            sleep 5
        fi
        if docker compose pull; then
            return 0
        fi
        attempt=$((attempt + 1))
    done
    return 1
}

# --- Resolve project directory ------------------------------------------------

get_project_dir() {
    # If INSTALL_DIR is set externally, use it
    if [ -n "${INSTALL_DIR:-}" ]; then
        echo "$INSTALL_DIR"
        return
    fi
    # If we are inside the installer/ folder, go up one level
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local parent_dir
    parent_dir="$(dirname "$script_dir")"
    if [ -f "$parent_dir/$STUDIO_COMPOSE_FILE" ]; then
        echo "$parent_dir"
        return
    fi
    # If compose file is in the current directory
    if [ -f "./$STUDIO_COMPOSE_FILE" ]; then
        pwd
        return
    fi
    # Default to user's home
    echo "$HOME/diskrot-studio"
}

# ==============================================================================
#  UPDATE MODE
# ==============================================================================

do_update() {
    print_banner "studio///diskrot -- Update"
    local project_dir
    project_dir="$(get_project_dir)"

    if [ ! -f "$project_dir/$STUDIO_COMPOSE_FILE" ]; then
        print_fail "Cannot find $STUDIO_COMPOSE_FILE in $project_dir"
        echo "  Run the installer first, or set INSTALL_DIR."
        exit 1
    fi

    cd "$project_dir"

    # Pull latest repo changes if it is a git repo
    if [ -d ".git" ]; then
        print_step "Pulling latest repository changes..."
        if git pull --ff-only; then
            print_ok "Repository updated."
        else
            print_warn "Git pull failed -- continuing with image update."
        fi
    fi

    print_step "Pulling latest Docker images..."
    if ! docker_compose_pull_with_retry 3; then
        print_fail "Docker compose pull failed after 3 attempts."
        exit 1
    fi
    print_ok "Images pulled."

    print_step "Restarting the stack..."
    if ! docker compose up -d; then
        print_fail "Docker compose up failed."
        exit 1
    fi
    print_ok "Stack restarted."

    print_step "Pruning old images..."
    docker image prune -f
    print_ok "Cleanup complete."

    print_banner "Update Complete"
    echo "  Studio is running at: http://localhost:3000"
    echo ""
    open "http://localhost:3000"
}

# ==============================================================================
#  UNINSTALL MODE
# ==============================================================================

do_uninstall() {
    print_banner "studio///diskrot -- Uninstall"
    local project_dir
    project_dir="$(get_project_dir)"

    if [ ! -f "$project_dir/$STUDIO_COMPOSE_FILE" ]; then
        print_fail "Cannot find $STUDIO_COMPOSE_FILE in $project_dir"
        exit 1
    fi

    cd "$project_dir"

    print_step "Stopping all containers..."
    docker compose down
    print_ok "Containers stopped."

    echo ""
    read -rp "Remove Docker volumes (database + model cache)? This DELETES all data. (y/N) " answer
    if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
        print_step "Removing volumes..."
        docker compose down -v
        print_ok "Volumes removed."
    fi

    print_step "Pruning unused images..."
    docker image prune -f
    print_ok "Cleanup complete."

    print_banner "Uninstall Complete"
    echo "  Docker Desktop was NOT removed."
    echo "  Drag it to Trash from /Applications if desired."
}

# ==============================================================================
#  MAIN INSTALLER
# ==============================================================================

do_install() {
    print_banner "studio///diskrot -- macOS Installer"

    local project_dir
    project_dir="$(get_project_dir)"

    # -- Step 1: Xcode Command Line Tools (for git) ----------------------------
    print_banner "Step 1: Xcode Command Line Tools"

    if xcode-select -p >/dev/null 2>&1; then
        print_ok "Xcode Command Line Tools installed."
    else
        print_step "Installing Xcode Command Line Tools..."
        xcode-select --install 2>/dev/null || true
        echo ""
        echo "  A system dialog should appear. Click 'Install' and wait for it to finish."
        echo ""
        read -rp "Press Enter after the installation completes to continue..."
        if xcode-select -p >/dev/null 2>&1; then
            print_ok "Xcode Command Line Tools installed."
        else
            print_warn "Could not confirm installation. Continuing anyway..."
        fi
    fi

    # -- Step 2: Homebrew ------------------------------------------------------
    print_banner "Step 2: Homebrew"

    if command_exists brew; then
        print_ok "Homebrew is installed."
    else
        print_step "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add brew to PATH for the rest of this script
        if [ -f "/opt/homebrew/bin/brew" ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -f "/usr/local/bin/brew" ]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi

        if command_exists brew; then
            print_ok "Homebrew installed."
        else
            print_fail "Homebrew installation failed."
            echo "  Visit https://brew.sh for manual installation."
            exit 1
        fi
    fi

    # -- Step 3: Docker Desktop ------------------------------------------------
    print_banner "Step 3: Docker Desktop"

    if command_exists docker; then
        print_ok "Docker CLI found."

        if docker_running; then
            print_ok "Docker Desktop is running."
        else
            print_step "Starting Docker Desktop..."
            open -a "Docker" 2>/dev/null || true
            if ! wait_for_docker 120; then
                print_fail "Docker Desktop did not start within 120 seconds."
                echo "  Please start Docker Desktop manually and re-run the installer."
                exit 1
            fi
        fi
    else
        print_step "Docker not found. Installing Docker Desktop..."

        if command_exists brew; then
            print_step "Installing via Homebrew..."
            if brew install --cask docker; then
                print_ok "Docker Desktop installed via Homebrew."
            else
                print_warn "Homebrew install failed. Trying direct download..."
                install_docker_dmg
            fi
        else
            install_docker_dmg
        fi

        print_step "Starting Docker Desktop..."
        open -a "Docker" 2>/dev/null || true

        if ! wait_for_docker 180; then
            print_fail "Docker Desktop is not responding."
            echo "  Please start Docker Desktop from your Applications folder and re-run."
            exit 1
        fi
    fi

    # -- Step 4: Project Setup -------------------------------------------------
    print_banner "Step 4: Project Setup"

    if [ ! -f "$project_dir/$STUDIO_COMPOSE_FILE" ]; then
        if command_exists git; then
            print_step "Cloning studio///diskrot to $project_dir..."
            if ! git clone -b stable "$STUDIO_REPO" "$project_dir"; then
                print_fail "Git clone failed."
                exit 1
            fi
            print_ok "Repository cloned."
        else
            print_fail "git is not installed and the project is not at $project_dir."
            echo "  Install Xcode CLT (xcode-select --install) and re-run."
            exit 1
        fi
    else
        print_ok "Project found at $project_dir"
    fi

    # Create data directories
    mkdir -p "$project_dir/data/acestep-checkpoints"
    mkdir -p "$project_dir/data/acestep-output"
    mkdir -p "$project_dir/data/yulan-hf-cache"
    mkdir -p "$project_dir/data/yulan-gguf"
    mkdir -p "$project_dir/data/ltx-checkpoints"
    mkdir -p "$project_dir/data/ltx-output"
    print_ok "Data directories ready."

    # -- Step 5: Environment Configuration -------------------------------------
    print_banner "Step 5: Environment Configuration"

    local env_file="$project_dir/.env"
    local write_env=false

    if [ -f "$env_file" ]; then
        print_ok ".env file already exists."
        read -rp "Overwrite .env with fresh defaults? (y/N) " answer
        if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
            write_env=true
        else
            print_step "Keeping existing .env file."
        fi
    else
        write_env=true
    fi

    if [ "$write_env" = true ]; then
        # Prompt for Hugging Face token
        echo ""
        echo "  A Hugging Face token is required to download AI model weights."
        echo "  Create one at: https://huggingface.co/settings/tokens"
        echo "  (select 'Read' access)"
        echo ""
        printf "  Hugging Face token (hf_...): "
        read -r hf_token
        if [ -z "$hf_token" ]; then
            print_warn "No token entered. Model downloads may fail without a valid token."
            echo "  You can set HF_TOKEN later in the .env file."
        else
            print_ok "Hugging Face token saved."
        fi

        cat > "$env_file" << ENVEOF
POSTGRES_USER=studio
POSTGRES_PASSWORD=studio
POSTGRES_DB=studio
POSTGRES_PORT=5432

REDIS_PORT=6379

PGADMIN_DEFAULT_EMAIL=admin@diskrot.studio
PGADMIN_DEFAULT_PASSWORD=admin
PGADMIN_PORT=5050

REDISINSIGHT_PORT=5540

BACKEND_PORT=8080
UI_PORT=3000
BUILD_ENV=local

# Mac always uses CPU mode (no NVIDIA GPU)
ACESTEP_VARIANT=cpu
YULAN_VARIANT=cpu
LTX_VARIANT=cpu
COMPOSE_FILE=docker-compose.yml
# Hugging Face token for model downloads (get one at https://huggingface.co/settings/tokens)
HF_TOKEN=${hf_token}
ENVEOF
        print_ok ".env configured (mode: cpu)."
    fi

    # -- Step 6: Pull Images and Launch ----------------------------------------
    print_banner "Step 6: Pull Images and Launch"

    cd "$project_dir"

    print_step "Pulling Docker images (this may take a while on first run)..."
    if ! docker_compose_pull_with_retry 5; then
        print_fail "Docker compose pull failed after 5 attempts."
        echo "  Check your internet connection and Docker Desktop status."
        exit 1
    fi
    print_ok "All images pulled."

    print_step "Starting the stack..."
    if ! docker compose up -d; then
        print_fail "Docker compose up failed."
        exit 1
    fi
    print_ok "Stack is starting up."

    print_step "Pruning old images..."
    docker image prune -f

    # -- Done ------------------------------------------------------------------
    print_banner "Installation Complete!"

    echo "  studio///diskrot is starting up."
    echo ""
    echo "  First startup downloads AI model weights and may take several minutes."
    echo "  Subsequent starts are fast (models are cached locally)."
    echo ""
    echo "  Studio UI:     http://localhost:3000"
    echo "  pgAdmin:       http://localhost:5050"
    echo "  RedisInsight:  http://localhost:5540"
    echo ""
    echo "  To update later:  ./start.sh (or ./installer/install.sh --update)"
    echo "  To stop:          docker compose down"
    echo "  To uninstall:     ./installer/install.sh --uninstall"
    echo ""

    # Open browser
    open "http://localhost:3000"
}

# --- Helper: install Docker Desktop via DMG download --------------------------

install_docker_dmg() {
    local arch
    arch="$(uname -m)"
    local url
    if [ "$arch" = "arm64" ]; then
        url="$DOCKER_DMG_URL_ARM"
    else
        url="$DOCKER_DMG_URL_X86"
    fi

    print_step "Downloading Docker Desktop DMG..."
    local dmg_path="/tmp/Docker.dmg"
    curl -fSL "$url" -o "$dmg_path"

    print_step "Mounting and installing Docker Desktop..."
    hdiutil attach "$dmg_path" -nobrowse -quiet
    cp -R "/Volumes/Docker/Docker.app" "/Applications/"
    hdiutil detach "/Volumes/Docker" -quiet
    rm -f "$dmg_path"
    print_ok "Docker Desktop installed."
}

# ==============================================================================
#  AUTO-DETECT: is this a fresh install or an update?
# ==============================================================================

is_already_installed() {
    command_exists docker || return 1
    docker_running       || return 1
    local project_dir
    project_dir="$(get_project_dir)"
    [ -f "$project_dir/.env" ] || return 1
    return 0
}

# ==============================================================================
#  ENTRY POINT
# ==============================================================================

MODE="${1:-}"

case "$MODE" in
    --update|-u)
        do_update
        ;;
    --uninstall|-r)
        do_uninstall
        ;;
    *)
        # Auto-detect: if everything is already set up, do an update
        if is_already_installed; then
            print_banner "Existing installation detected"
            echo "  Docker is running and .env exists -- switching to update mode."
            echo ""
            do_update
        else
            do_install
        fi
        ;;
esac
