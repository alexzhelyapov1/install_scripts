#!/bin/bash
# Installs requirements/snap.txt.

set -euo pipefail

cd $(dirname "$0")/..
source lib/common.sh

# --- Variables ---
SNAP_LIST="requirements/snap.txt"

# --- 1. Packages ---
while read -r name flags; do
    if snap list "$name" >/dev/null 2>&1; then
        log_info "snap is installed: $name"
        continue
    fi
    log_info "Installing snap: $name $flags"
    # shellcheck disable=SC2086
    sudo snap install "$name" $flags
    mark_changed "Installed snap $name"
done < <(read_list "$SNAP_LIST")
