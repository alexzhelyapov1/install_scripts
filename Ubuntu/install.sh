#!/bin/bash

set -euo pipefail

cd $(dirname "$0")
source lib/common.sh

# --- Variables ---
STEPS=(
    storage
    apt
    snap
    tools
    shell
    vscode
    gnome
    git
    repos
    services
    agents
    system
)
LOG_DIR="$HOME/.cache/install_scripts"
LOG_FILE="$LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log"
MANUAL_BINARIES=(tiny mplc mpl-format llcache)

usage() {
    local IFS="|"
    cat <<EOF
Usage: $0 [step...]   Run all steps or only the listed ones, in the order of the list below.
       $0 diff        Show what is installed on the system but missing in the lists, and back.
Steps: ${STEPS[*]}
EOF
}

# --- 1. Arguments ---
if [ "$#" -eq 1 ] && [ "$1" == "diff" ]; then
    exec ./diff.sh
fi

SELECTED_STEPS=()
if [ "$#" -eq 0 ]; then
    SELECTED_STEPS=("${STEPS[@]}")
else
    for arg in "$@"; do
        if [[ ! " ${STEPS[*]} " =~ " $arg " ]]; then
            usage
            log_error "Unknown step: '$arg'"
        fi
    done
    for step in "${STEPS[@]}"; do
        if [[ " $* " =~ " $step " ]]; then
            SELECTED_STEPS+=("$step")
        fi
    done
fi

# --- 2. System checks ---
if ! command -v lsb_release >/dev/null || [ "$(lsb_release -is)" != "Ubuntu" ] || [ "$(lsb_release -rs)" != "24.04" ]; then
    log_error "This script is for Ubuntu 24.04 only."
fi

if [ "$(id -u)" -eq 0 ]; then
    log_error "Run this script as a regular user, without sudo: $0\nIt calls sudo itself where needed."
fi

if ! command -v git >/dev/null; then
    log_error "git is not installed."
fi

if ! ls "$HOME"/.ssh/id_* >/dev/null 2>&1; then
    log_error "No ssh key found in ~/.ssh. Copy your key there first (GitHub repositories are cloned over ssh)."
fi

load_env_local

# --- 3. Sudo ---
# Ask for the password once and keep the sudo timestamp fresh while the steps run.
log_info "Requesting sudo..."
sudo -v
while true; do
    sudo -n true
    sleep 50
    kill -0 "$$" 2>/dev/null || exit
done 2>/dev/null &
SUDO_KEEPALIVE_PID=$!

export INSTALL_STATE_DIR
INSTALL_STATE_DIR="$(mktemp -d)"
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null; rm -rf "$INSTALL_STATE_DIR"' EXIT

mkdir -p "$LOG_DIR"
log_info "Log: $LOG_FILE"

# --- 4. Steps ---
# Every step runs in its own process: a failed step is reported and the next one still runs.
declare -A STEP_STATUS
for step in "${SELECTED_STEPS[@]}"; do
    echo
    log_info "========== Step: $step =========="
    if INSTALL_STEP="$step" bash "steps/$step.sh" 2>&1 | tee -a "$LOG_FILE"; then
        if [ -s "$INSTALL_STATE_DIR/changed-$step" ]; then
            STEP_STATUS[$step]="${COLOR_GREEN}OK${COLOR_RESET}"
        else
            STEP_STATUS[$step]="${COLOR_BLUE}UNCHANGED${COLOR_RESET}"
        fi
    else
        STEP_STATUS[$step]="${COLOR_RED}FAIL${COLOR_RESET}"
        echo "[$step] Step failed, see the log." >> "$INSTALL_STATE_DIR/todo"
    fi
done

# --- 5. Checks for things the steps don't install ---
for binary in "${MANUAL_BINARIES[@]}"; do
    if [ ! -x "$GRAVILINK_DIR/.bin/$binary" ]; then
        echo "[final] Put the '$binary' binary into $GRAVILINK_DIR/.bin" >> "$INSTALL_STATE_DIR/todo"
    fi
done

# --- Completion ---
echo
log_info "========== Report =========="
for step in "${SELECTED_STEPS[@]}"; do
    printf "  %-10s %b\n" "$step" "${STEP_STATUS[$step]}"
done

echo
if [ -s "$INSTALL_STATE_DIR/todo" ]; then
    log_warning "Manual steps:"
    awk '!seen[$0]++' "$INSTALL_STATE_DIR/todo" | sed 's/^/  - /'
else
    log_ok "Nothing to do manually."
fi

echo
log_info "Full log: $LOG_FILE"
log_info "Open a new terminal (or run 'source ~/.bashrc') to get the new environment."
