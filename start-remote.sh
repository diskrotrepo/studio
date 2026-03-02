#!/usr/bin/env bash
# studio///diskrot -- Start (Remote)
# Run this script to install or update studio///diskrot in remote mode.
# First run: installs prerequisites (Homebrew, Docker Desktop) and launches.
# Subsequent runs: pulls latest images and restarts the stack.
#
# Only starts postgres, redis, studio-backend, and studio-ui — the minimum
# services required to communicate with a remote studio///diskrot instance.

set -euo pipefail

# ── colors ───────────────────────────────────────────────
C='\033[36m'   BC='\033[96m'
M='\033[35m'   BM='\033[95m'
W='\033[97m'   DK='\033[90m'
N='\033[0m'

# ── intro ────────────────────────────────────────────────
clear

_l() { sleep 0.02; echo -e "$1"; }

echo ""
_l "${DK}  ──────────────────────────────────────────────────────────${N}"
_l ""
_l "${BC}    ██████╗ ██╗███████╗██╗  ██╗██████╗  ██████╗ ████████╗${N}"
_l "${C}    ██╔══██╗██║██╔════╝██║ ██╔╝██╔══██╗██╔═══██╗╚══██╔══╝${N}"
_l "${BM}    ██║  ██║██║███████╗█████╔╝ ██████╔╝██║   ██║   ██║   ${N}"
_l "${M}    ██║  ██║██║╚════██║██╔═██╗ ██╔══██╗██║   ██║   ██║   ${N}"
_l "${BC}    ██████╔╝██║███████║██║  ██╗██║  ██║╚██████╔╝   ██║   ${N}"
_l "${C}    ╚═════╝ ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝    ╚═╝   ${N}"
_l ""
_l "${W}                      s t u d i o///diskrot${N}"
_l "${DK}                        [ remote ]${N}"
_l ""
_l "${DK}  ──────────────────────────────────────────────────────────${N}"
_l "${DK}       diskrot.com · 2026${N}"
_l "${DK}  ──────────────────────────────────────────────────────────${N}"
echo ""

sleep 0.3

# loading bar
printf "  ${DK}"
for i in $(seq 1 50); do
    printf "▓"
    sleep 0.012
done
printf "${N}\n\n"

echo -e "  ${BC}▸${N} initializing...\n"

# ── launch ───────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export COMPOSE_FILE="docker-compose.remote.yml"
exec bash "$SCRIPT_DIR/installer/install.sh" "$@"
