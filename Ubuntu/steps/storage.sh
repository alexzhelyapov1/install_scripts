#!/bin/bash
# Mounts /mnt/storage (bind mount of a home directory or a disk, see storage.conf) and the work directory in it.

set -euo pipefail

cd $(dirname "$0")/..
source lib/common.sh
load_env_local

# --- Variables ---
STORAGE_PATH="/mnt/storage"
STORAGE_BIND=""
STORAGE_DISK_UUID=""
source storage.conf

if [ -n "$STORAGE_BIND" ] && [ -n "$STORAGE_DISK_UUID" ]; then
    log_error "storage.conf: set either STORAGE_BIND or STORAGE_DISK_UUID, not both."
fi

# --- 1. /mnt/storage ---
if [ -n "$STORAGE_BIND" ]; then
    if [ ! -d "$STORAGE_BIND" ]; then
        mkdir -p "$STORAGE_BIND"
        mark_changed "Created $STORAGE_BIND"
    fi
    # Earlier versions linked /mnt/storage to the same directory
    if [ -L "$STORAGE_PATH" ] && [ "$(readlink "$STORAGE_PATH")" == "$STORAGE_BIND" ]; then
        sudo rm "$STORAGE_PATH"
        mark_changed "Removed the old link $STORAGE_PATH -> $STORAGE_BIND"
    fi
    FSTAB_SOURCE="$STORAGE_BIND"
    FSTAB_LINE="$STORAGE_BIND $STORAGE_PATH none bind,nofail,x-systemd.requires-mounts-for=$(dirname "$STORAGE_BIND") 0 0"
elif [ -n "$STORAGE_DISK_UUID" ]; then
    if [ ! -e "/dev/disk/by-uuid/$STORAGE_DISK_UUID" ]; then
        log_error "Disk with UUID $STORAGE_DISK_UUID not found. Check 'lsblk -f'."
    fi
    FSTAB_SOURCE="UUID=$STORAGE_DISK_UUID"
    FSTAB_LINE="UUID=$STORAGE_DISK_UUID $STORAGE_PATH auto defaults,nofail 0 2"
else
    log_error "storage.conf: set STORAGE_BIND or STORAGE_DISK_UUID."
fi

if awk -v src="$FSTAB_SOURCE" -v dst="$STORAGE_PATH" '$1 == src && $2 == dst {found = 1} END {exit !found}' /etc/fstab; then
    log_info "$FSTAB_SOURCE is already in /etc/fstab"
elif [ -L "$STORAGE_PATH" ] || { [ -d "$STORAGE_PATH" ] && [ -n "$(ls -A "$STORAGE_PATH")" ]; }; then
    report_todo "$STORAGE_PATH exists and is not empty, $FSTAB_SOURCE was not added to /etc/fstab (storage.conf). Left as is."
else
    sudo mkdir -p "$STORAGE_PATH"
    echo "$FSTAB_LINE" | sudo tee -a /etc/fstab > /dev/null
    mark_changed "Added $FSTAB_SOURCE -> $STORAGE_PATH to /etc/fstab"
fi

if awk -v src="$FSTAB_SOURCE" -v dst="$STORAGE_PATH" '$1 == src && $2 == dst {found = 1} END {exit !found}' /etc/fstab \
    && ! mountpoint -q "$STORAGE_PATH"; then
    sudo systemctl daemon-reload
    sudo mount "$STORAGE_PATH"
    mark_changed "Mounted $STORAGE_PATH"
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
