#!/bin/bash
# Shared helpers for install.sh, diff.sh and steps/*.sh. Source it, don't run it.

# --- Variables ---
UBUNTU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_LOCAL="$UBUNTU_DIR/dotfiles/bash/env.local"
BACKUP_DIR="$HOME/.cache/install_scripts/backup"

# --- Colors for logs ---
COLOR_RESET='\033[0m'
COLOR_ORANGE='\033[0;33m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_BLUE='\033[0;34m'

# --- Logging functions ---
log_info() {
    echo -e "${COLOR_BLUE}[INFO] $1${COLOR_RESET}"
}

log_ok() {
    echo -e "${COLOR_GREEN}[OK] $1${COLOR_RESET}"
}

log_warning() {
    echo -e "${COLOR_ORANGE}[WARNING] $1${COLOR_RESET}"
}

log_error() {
    echo -e "${COLOR_RED}[ERROR] $1${COLOR_RESET}" >&2
    exit 1
}

# --- Report functions ---
# install.sh sets INSTALL_STATE_DIR and INSTALL_STEP. Outside of it the records are dropped.

# Records that the step changed the system. A step without records is reported as UNCHANGED.
mark_changed() {
    log_ok "$1"
    if [ -n "${INSTALL_STATE_DIR:-}" ]; then
        echo "$1" >> "$INSTALL_STATE_DIR/changed-$INSTALL_STEP"
    fi
}

# Adds a line to the "Manual steps" section of the final report.
report_todo() {
    log_warning "TODO: $1"
    if [ -n "${INSTALL_STATE_DIR:-}" ]; then
        echo "[$INSTALL_STEP] $1" >> "$INSTALL_STATE_DIR/todo"
    fi
}

# --- Environment ---
load_env_local() {
    if [ ! -f "$ENV_LOCAL" ]; then
        log_error "Can't find $ENV_LOCAL\nCreate it from the template and check the values:\n  cp $ENV_LOCAL.example $ENV_LOCAL"
    fi
    # shellcheck source=/dev/null
    source "$ENV_LOCAL"
}

# Reads a list file: one item per line, '#' comments and empty lines are skipped.
read_list() {
    grep -vE '^\s*#|^\s*$' "$1" | sed 's/\s*$//'
}

# --- Files ---
# Moves an existing path into the backup directory, keeping its path relative to /.
backup_path() {
    local path="$1"
    local target
    target="$BACKUP_DIR/$(date +%Y%m%d-%H%M%S)$path"
    mkdir -p "$(dirname "$target")"
    mv "$path" "$target"
    log_warning "Moved $path to $target"
}

# Makes dst a symlink to src. Anything else at dst is moved to the backup first.
link_config() {
    local src="$1"
    local dst="$2"

    if [ -L "$dst" ] && [ "$(readlink "$dst")" == "$src" ]; then
        log_info "Link is up to date: $dst"
        return 0
    fi

    mkdir -p "$(dirname "$dst")"
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        backup_path "$dst"
    fi
    ln -s "$src" "$dst"
    mark_changed "Linked $dst -> $src"
}

# Writes stdin to dst only if the content differs. Pass "sudo" as the second argument for system files.
write_file() {
    local dst="$1"
    local use_sudo="${2:-}"
    local content
    content="$(cat)"

    if [ -f "$dst" ] && [ "$(cat "$dst")" == "$content" ]; then
        log_info "File is up to date: $dst"
        return 0
    fi

    $use_sudo mkdir -p "$(dirname "$dst")"
    printf '%s\n' "$content" | $use_sudo tee "$dst" > /dev/null
    mark_changed "Wrote $dst"
}

# Puts stdin into file between the "# <marker> BEGIN" and "# <marker> END" lines.
# An existing block is replaced in place, so the content of the block can change between runs.
write_marker_block() {
    local file="$1"
    local marker="$2"
    local separator="# ----------------------------------------------------------------------------------------------------------------------"
    local block
    block="$(printf '%s\n# %s BEGIN\n%s\n# %s END\n%s' "$separator" "$marker" "$(cat)" "$marker" "$separator")"

    touch "$file"
    if ! grep -qxF "# $marker BEGIN" "$file"; then
        printf '\n%s\n' "$block" >> "$file"
        mark_changed "Added block $marker to $file"
        return 0
    fi

    local new_file
    new_file="$(mktemp)"
    BEGIN_LINE="# $marker BEGIN" END_LINE="# $marker END" SEPARATOR="$separator" BLOCK="$block" awk '
        { lines[NR] = $0 }
        END {
            for (i = 1; i <= NR; i++) {
                if (lines[i] == ENVIRON["BEGIN_LINE"]) {
                    start = (i > 1 && lines[i - 1] == ENVIRON["SEPARATOR"]) ? i - 1 : i
                    for (stop = i; stop < NR && lines[stop] != ENVIRON["END_LINE"]; stop++) {}
                    if (stop < NR && lines[stop + 1] == ENVIRON["SEPARATOR"]) { stop++ }
                    break
                }
            }
            for (i = 1; i <= NR; i++) {
                if (i == start) { print ENVIRON["BLOCK"] }
                if (i < start || i > stop) { print lines[i] }
            }
        }' "$file" > "$new_file"

    if cmp -s "$file" "$new_file"; then
        rm -f "$new_file"
        log_info "Block $marker is up to date in $file"
        return 0
    fi
    cat "$new_file" > "$file"
    rm -f "$new_file"
    mark_changed "Updated block $marker in $file"
}

# --- Packages ---
apt_is_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

# Installs the packages that are not installed yet.
apt_install() {
    local missing=()
    local package
    for package in "$@"; do
        if ! apt_is_installed "$package"; then
            missing+=("$package")
        fi
    done

    if [ ${#missing[@]} -eq 0 ]; then
        log_info "All apt packages are installed: $*"
        return 0
    fi

    log_info "Installing apt packages: ${missing[*]}"
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing[@]}"
    mark_changed "Installed apt packages: ${missing[*]}"
}
