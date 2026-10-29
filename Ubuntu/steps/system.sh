#!/bin/bash
# System settings: docker group, GRUB menu timeout on dual boot machines.

set -euo pipefail

cd $(dirname "$0")/..
source lib/common.sh

# --- Variables ---
GRUB_CONFIG="/etc/default/grub"
GRUB_TIMEOUT_SECONDS="15"

# --- 1. Docker without sudo ---
if grep -qw docker <<< "$(id -nG "$USER")"; then
    log_info "$USER is in the docker group"
elif getent group docker >/dev/null; then
    sudo usermod -aG docker "$USER"
    mark_changed "Added $USER to the docker group"
    report_todo "Log out and log in again: the docker group applies to new sessions"
else
    log_warning "The docker group doesn't exist (the apt step installs docker)"
fi

# --- 2. GRUB timeout, only when there is a second OS ---
if [ -z "$(sudo os-prober 2>/dev/null)" ]; then
    log_info "No second OS found, GRUB is left as is"
elif grep -qx "GRUB_TIMEOUT=$GRUB_TIMEOUT_SECONDS" "$GRUB_CONFIG"; then
    log_info "GRUB_TIMEOUT is up to date"
else
    sudo sed -i "s/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=$GRUB_TIMEOUT_SECONDS/" "$GRUB_CONFIG"
    sudo update-grub
    mark_changed "Set GRUB_TIMEOUT=$GRUB_TIMEOUT_SECONDS"
fi
