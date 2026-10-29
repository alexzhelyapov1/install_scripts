#!/bin/bash
# System settings: docker group, GRUB menu timeout on dual boot machines, no swap.

set -euo pipefail

cd $(dirname "$0")/..
source lib/common.sh

# --- Variables ---
GRUB_CONFIG="/etc/default/grub"
GRUB_TIMEOUT_SECONDS="15"
FSTAB="/etc/fstab"
# Swap file of the Ubuntu installer
SWAP_FILE="/swap.img"

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

# --- 3. No swap ---
# With plenty of RAM swapping only freezes the system, the OOM killer is the better outcome.
# vm.swappiness=0 is not enough: the kernel still swaps under memory pressure.
if [ -n "$(swapon --noheadings --show=NAME)" ]; then
    sudo swapoff -a
    mark_changed "Turned swap off"
else
    log_info "Swap is off"
fi

# Swap entries stay in fstab as comments, so they don't come back after a reboot and are easy to restore
if awk '$1 !~ /^#/ && $3 == "swap" {found = 1} END {exit !found}' "$FSTAB"; then
    sudo sed -i -E 's|^([^#][^[:space:]]*[[:space:]]+[^[:space:]]+[[:space:]]+swap[[:space:]].*)$|# \1|' "$FSTAB"
    sudo systemctl daemon-reload
    mark_changed "Commented out swap entries in $FSTAB"
else
    log_info "No swap entries in $FSTAB"
fi

if [ -f "$SWAP_FILE" ]; then
    sudo rm "$SWAP_FILE"
    mark_changed "Removed $SWAP_FILE"
fi
