#!/bin/bash
# Links VS Code settings into the repository and installs requirements/vscode.txt.

set -euo pipefail

cd $(dirname "$0")/..
source lib/common.sh

# --- Variables ---
VSCODE_USER_DIR="$HOME/.config/Code/User"
EXTENSIONS_LIST="requirements/vscode.txt"

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

if ! grep -qE '\.mpl$' <<< "$INSTALLED"; then
    report_todo "Install the MPL VS Code extension from its .vsix: code --install-extension <file>.vsix"
fi
