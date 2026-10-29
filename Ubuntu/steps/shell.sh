#!/bin/bash
# Connects dotfiles/bash/env.sh to ~/.bashrc and links the fish configs into the repository.

set -euo pipefail

cd $(dirname "$0")/..
source lib/common.sh

# --- Variables ---
BASHRC="$HOME/.bashrc"
BASHRC_MARKER="INSTALL_SCRIPTS_ENV"
OLD_BASHRC_MARKER="BASH_WORK_ENV_BLOCK"
FISH_DIR="$HOME/.config/fish"
DOTFILES="$UBUNTU_DIR/dotfiles"

# --- 1. ~/.bashrc ---
if grep -qF "$OLD_BASHRC_MARKER" "$BASHRC"; then
    report_todo "~/.bashrc still has the old $OLD_BASHRC_MARKER block and manual exports (MPL, nvm, emsdk, curl). Remove them: env.sh sets all of it."
fi

write_marker_block "$BASHRC" "$BASHRC_MARKER" <<EOF
# Environment from install_scripts. Edit $DOTFILES/bash/env.sh, not this block.
[ -f "$DOTFILES/bash/env.sh" ] && source "$DOTFILES/bash/env.sh"
EOF

# --- 2. fish ---
link_config "$DOTFILES/fish/config.fish" "$FISH_DIR/config.fish"
link_config "$DOTFILES/fish/config_slm.fish" "$FISH_DIR/config_slm.fish"
for function_file in "$DOTFILES"/fish/functions/*.fish; do
    link_config "$function_file" "$FISH_DIR/functions/$(basename "$function_file")"
done
