#!/bin/bash
# GNOME settings: keyboard layouts and Alt+Shift layout switching.

set -euo pipefail

cd $(dirname "$0")/..
source lib/common.sh

# Sets a gsettings key only if the current value differs.
# The value must be written the way 'gsettings get' prints it, otherwise it is set on every run (harmless).
gsettings_ensure() {
    local schema="$1"
    local key="$2"
    local value="$3"

    if [ "$(gsettings get "$schema" "$key")" == "$value" ]; then
        log_info "$schema $key is up to date"
        return 0
    fi
    gsettings set "$schema" "$key" "$value"
    mark_changed "Set $schema $key to $value"
}

if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    log_error "No GNOME session (DBUS_SESSION_BUS_ADDRESS is empty). Run this step from a terminal inside the desktop session."
fi

# --- 1. Keyboard layouts ---
gsettings_ensure org.gnome.desktop.input-sources sources "[('xkb', 'us+colemak'), ('xkb', 'ru')]"

# --- 2. Alt+Shift switches the layout ---
# Done with the GNOME shortcut, xkb options stay empty, so the switch is not bound twice.
gsettings_ensure org.gnome.desktop.input-sources xkb-options "@as []"
gsettings_ensure org.gnome.desktop.wm.keybindings switch-input-source "['<Alt>Shift_L', '<Alt>Shift_R', '<Shift>Alt_L', '<Shift>Alt_R']"
