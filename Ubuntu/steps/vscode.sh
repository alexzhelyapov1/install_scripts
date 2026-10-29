#!/bin/bash
# Links VS Code settings into the repository and installs requirements/vscode.txt.

set -euo pipefail

cd $(dirname "$0")/..
source lib/common.sh
load_env_local

# --- Variables ---
VSCODE_USER_DIR="$HOME/.config/Code/User"
EXTENSIONS_LIST="requirements/vscode.txt"
# The MPL extension is not in the marketplace, its .vsix lies next to the work repositories
MPL_VSIX_GLOB="$GRAVILINK_DIR/mpl-*.vsix"

if ! command -v code >/dev/null; then
    log_error "VS Code is not installed (the apt step installs it)."
fi

# --- 1. Settings ---
link_config "$UBUNTU_DIR/dotfiles/vscode/settings.json" "$VSCODE_USER_DIR/settings.json"
link_config "$UBUNTU_DIR/dotfiles/vscode/keybindings.json" "$VSCODE_USER_DIR/keybindings.json"

# --- 2. Extensions ---
INSTALLED="$(code --list-extensions | tr '[:upper:]' '[:lower:]')"
while read -r extension; do
    if grep -qxF "${extension,,}" <<< "$INSTALLED"; then
        log_info "Extension is installed: $extension"
    else
        code --install-extension "$extension"
        mark_changed "Installed extension $extension"
    fi
done < <(read_list "$EXTENSIONS_LIST")

if grep -qE '\.mpl$' <<< "$INSTALLED"; then
    log_info "Extension is installed: MPL"
else
    MPL_VSIX="$(ls $MPL_VSIX_GLOB 2>/dev/null | sort -V | tail -n 1 || true)"
    if [ -n "$MPL_VSIX" ]; then
        code --install-extension "$MPL_VSIX"
        mark_changed "Installed extension $MPL_VSIX"
    else
        report_todo "Put the MPL extension at $MPL_VSIX_GLOB and run ./install.sh vscode"
    fi
fi
