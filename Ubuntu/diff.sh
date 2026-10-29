#!/bin/bash
# Compares the system with the lists in requirements/. Changes nothing.
#   + installed on the system, missing in the list (add it to the list or remove it from the system)
#   - in the list, missing on the system (run ./install.sh)

set -euo pipefail

cd $(dirname "$0")
source lib/common.sh
load_env_local

# --- Variables ---
# Snaps that come with Ubuntu or as dependencies of other snaps
DEFAULT_SNAPS_REGEX='^(bare|core[0-9]*|snapd|snapd-desktop-integration|snap-store|firmware-updater|firefox|thunderbird|gtk-common-themes|gnome-[0-9-]+|mesa-[0-9]+)$'
# apt packages that the Ubuntu installer marks as manual: locales, kernel, drivers, boot, input methods
DEFAULT_APT_REGEX='^(language-pack-.*|hyphen-.*|mythes-.*|libreoffice-(help|l10n)-.*|thunderbird-locale-.*|linux-.*|nvidia-.*|grub-.*|shim-signed|efibootmgr|iw|ibus-.*|lib(chewing|pinyin|m17n|opencc|marisa|otf)[0-9.-]*(-data)?|m17n-db|apparmor-(profiles|utils))$'
# Metapackages of the base system: their dependencies are not listed
BASE_METAPACKAGES=(ubuntu-desktop ubuntu-desktop-minimal ubuntu-minimal ubuntu-standard ubuntu-restricted-addons)
# npm packages that come with Node
DEFAULT_NPM_REGEX='^(npm|corepack)$'

# Prints the difference of a list and the system, all given as newline-separated strings.
# The optional fourth argument is everything installed, when the system list is filtered.
print_diff() {
    local title="$1"
    local system="$2"
    local list="$3"
    local installed="${4:-$2}"
    local extra
    local missing
    extra="$(comm -23 <(sort -u <<< "$system" | sed '/^$/d') <(sort -u <<< "$list" | sed '/^$/d'))"
    missing="$(comm -13 <(sort -u <<< "$installed" | sed '/^$/d') <(sort -u <<< "$list" | sed '/^$/d'))"

    echo
    log_info "$title"
    if [ -z "$extra" ] && [ -z "$missing" ]; then
        echo "  no differences"
        return 0
    fi
    [ -n "$extra" ] && sed 's/^/  + /' <<< "$extra"
    [ -n "$missing" ] && sed 's/^/  - /' <<< "$missing"
    return 0
}

# --- 1. apt ---
# Manually installed packages minus the base system: essential and important packages,
# dependencies of the Ubuntu metapackages and what the installer adds (DEFAULT_APT_REGEX)
APT_BASE="$(
    dpkg-query -W -f='${Package} ${Priority} ${Essential}\n' | awk '$2 == "required" || $2 == "important" || $3 == "yes" {print $1}'
    apt-cache depends --recurse --installed --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances \
        "${BASE_METAPACKAGES[@]}" 2>/dev/null | grep -E '^[a-z0-9]'
)"
APT_SYSTEM="$(comm -23 <(apt-mark showmanual | sort -u) <(sort -u <<< "$APT_BASE") | grep -vE "$DEFAULT_APT_REGEX" || true)"
APT_INSTALLED="$(dpkg-query -W -f='${Package} ${db:Status-Status}\n' | awk '$2 == "installed" {print $1}')"
print_diff "apt (requirements/apt.txt)" "$APT_SYSTEM" "$(read_list requirements/apt.txt)" "$APT_INSTALLED"

# --- 2. snap ---
SNAP_SYSTEM="$(snap list 2>/dev/null | awk 'NR > 1 {print $1}' | grep -vE "$DEFAULT_SNAPS_REGEX" || true)"
print_diff "snap (requirements/snap.txt)" "$SNAP_SYSTEM" "$(read_list requirements/snap.txt | awk '{print $1}')"

# --- 3. npm ---
if [ -s "$HOME/.nvm/nvm.sh" ]; then
    set +u
    source "$HOME/.nvm/nvm.sh"
    set -u
    NPM_SYSTEM="$(npm ls -g --depth=0 --parseable 2>/dev/null | tail -n +2 | sed 's|.*/node_modules/||' | grep -vE "$DEFAULT_NPM_REGEX" || true)"
    print_diff "npm global (requirements/npm.txt)" "$NPM_SYSTEM" "$(read_list requirements/npm.txt)"
fi

# --- 4. VS Code extensions ---
if command -v code >/dev/null; then
    print_diff "VS Code extensions (requirements/vscode.txt)" \
        "$(code --list-extensions | tr '[:upper:]' '[:lower:]')" \
        "$(read_list requirements/vscode.txt | tr '[:upper:]' '[:lower:]')"
fi

# --- 5. Repositories ---
REPOS_SYSTEM="$(find "$GRAVILINK_DIR" -mindepth 2 -maxdepth 3 -name .git -printf '%h\n' 2>/dev/null || true)"
for dir in "$WORK_SETUP_DIR" "$SENDME_BOT_DIR" "$TIME_LOGGER_DIR"; do
    [ -d "$dir/.git" ] && REPOS_SYSTEM+=$'\n'"$dir"
done
REPOS_LIST="$(read_list requirements/repos.txt | envsubst '$HOME $GRAVILINK_DIR $WORK_SETUP_DIR $SENDME_BOT_DIR $TIME_LOGGER_DIR' | awk '{print $2}')"
print_diff "repositories (requirements/repos.txt)" "$REPOS_SYSTEM" "$REPOS_LIST"
