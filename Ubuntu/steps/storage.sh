#!/bin/bash
# Creates /mnt/storage (symlink or disk mount, see storage.conf) and the work directory in it.

set -euo pipefail

cd $(dirname "$0")/..
source lib/common.sh
load_env_local

# --- Variables ---
STORAGE_PATH="/mnt/storage"
STORAGE_LINK=""
STORAGE_DISK_UUID=""
source storage.conf

if [ -n "$STORAGE_LINK" ] && [ -n "$STORAGE_DISK_UUID" ]; then
    log_error "storage.conf: set either STORAGE_LINK or STORAGE_DISK_UUID, not both."
fi

# --- 1. /mnt/storage ---
if [ -n "$STORAGE_LINK" ]; then
    if [ -L "$STORAGE_PATH" ] && [ "$(readlink "$STORAGE_PATH")" == "$STORAGE_LINK" ]; then
        log_info "$STORAGE_PATH already links to $STORAGE_LINK"
    elif [ -e "$STORAGE_PATH" ] || [ -L "$STORAGE_PATH" ]; then
        report_todo "$STORAGE_PATH exists but is not a link to $STORAGE_LINK (storage.conf). Left as is."
    else
        if [ ! -d "$STORAGE_LINK" ]; then
            mkdir -p "$STORAGE_LINK"
            mark_changed "Created $STORAGE_LINK"
        fi
        sudo mkdir -p "$(dirname "$STORAGE_PATH")"
        sudo ln -s "$STORAGE_LINK" "$STORAGE_PATH"
        mark_changed "Linked $STORAGE_PATH -> $STORAGE_LINK"
    fi
elif [ -n "$STORAGE_DISK_UUID" ]; then
    if grep -qE "^\s*UUID=$STORAGE_DISK_UUID\s" /etc/fstab; then
        log_info "Disk $STORAGE_DISK_UUID is already in /etc/fstab"
    elif [ -L "$STORAGE_PATH" ] || { [ -d "$STORAGE_PATH" ] && [ -n "$(ls -A "$STORAGE_PATH")" ]; }; then
        report_todo "$STORAGE_PATH exists and is not empty, disk $STORAGE_DISK_UUID was not added to /etc/fstab."
    else
        if [ ! -e "/dev/disk/by-uuid/$STORAGE_DISK_UUID" ]; then
            log_error "Disk with UUID $STORAGE_DISK_UUID not found. Check 'lsblk -f'."
        fi
        sudo mkdir -p "$STORAGE_PATH"
        echo "UUID=$STORAGE_DISK_UUID $STORAGE_PATH auto defaults,nofail 0 2" | sudo tee -a /etc/fstab > /dev/null
        mark_changed "Added disk $STORAGE_DISK_UUID to /etc/fstab"
    fi
    if ! mountpoint -q "$STORAGE_PATH"; then
        sudo systemctl daemon-reload
        sudo mount "$STORAGE_PATH"
        mark_changed "Mounted $STORAGE_PATH"
    fi
else
    log_error "storage.conf: set STORAGE_LINK or STORAGE_DISK_UUID."
fi

# --- 2. Work directory ---
if [ ! -d "$GRAVILINK_DIR" ]; then
    sudo mkdir -p "$GRAVILINK_DIR"
    mark_changed "Created $GRAVILINK_DIR"
fi
if [ "$(stat -c %U "$GRAVILINK_DIR")" != "$USER" ]; then
    sudo chown "$USER:$USER" "$GRAVILINK_DIR"
    mark_changed "Changed owner of $GRAVILINK_DIR to $USER"
fi
for dir in "$GRAVILINK_DIR/core" "$GRAVILINK_DIR/.bin"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        mark_changed "Created $dir"
    fi
done
