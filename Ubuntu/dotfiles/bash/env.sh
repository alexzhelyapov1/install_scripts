# ----------------------------------------------------------------------------------------------------------------------
# Environment for every bash shell, loaded from the INSTALL_SCRIPTS_ENV block in ~/.bashrc.
# Edit it here in the repository: new shells pick up the change. Machine-specific values live in env.local.
# Every addition to a path variable goes through env_prepend, so nested shells don't duplicate entries.
# ----------------------------------------------------------------------------------------------------------------------

INSTALL_SCRIPTS_UBUNTU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# --- Helpers ---
# Adds dir to the front of a ':'-separated variable, unless it is already there.
env_prepend() {
    local var="$1"
    local dir="$2"
    case ":${!var:-}:" in
        *":$dir:"*) ;;
        *) export "$var"="$dir${!var:+:${!var}}" ;;
    esac
}

# Installs apt packages and appends the new ones to requirements/apt.txt of this repository.
inst() {
    local apt_list="$INSTALL_SCRIPTS_UBUNTU_DIR/requirements/apt.txt"
    local package
    sudo apt-get install -y "$@" || return
    for package in "$@"; do
        if [[ "$package" != -* ]] && ! grep -qxF "$package" "$apt_list"; then
            echo "$package" >> "$apt_list"
            echo "[INFO] Added $package to $apt_list"
        fi
    done
}

# --- Machine-specific values ---
if [ -f "$INSTALL_SCRIPTS_UBUNTU_DIR/dotfiles/bash/env.local" ]; then
    source "$INSTALL_SCRIPTS_UBUNTU_DIR/dotfiles/bash/env.local"
else
    echo "[WARNING] $INSTALL_SCRIPTS_UBUNTU_DIR/dotfiles/bash/env.local not found, using defaults" >&2
fi
GRAVILINK_DIR="${GRAVILINK_DIR:-/mnt/storage/gravilink}"

# --- PATH ---
env_prepend PATH "$HOME/.local/bin"
env_prepend PATH "$GRAVILINK_DIR/.bin"

# --- MPL ---
export MPL_LIBS_PATH="$GRAVILINK_DIR/core"
export MPL_DIR="$GRAVILINK_DIR/.mpl_cache"
export MPL_SL_DIR="$GRAVILINK_DIR/core/mpl-sl"

# --- Node (nvm) ---
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"
# Global npm packages for scripts run with plain 'node' (sendme-bot/mdsendme)
if command -v node >/dev/null; then
    export NODE_PATH="$(dirname "$(dirname "$(command -v node)")")/lib/node_modules"
fi

# --- emsdk (WebAssembly toolchain for lab-engine web builds) ---
export EMSDK_QUIET=1
[ -f "$HOME/emsdk/emsdk_env.sh" ] && source "$HOME/emsdk/emsdk_env.sh" > /dev/null

# --- curl built from source (native builds need 8.15 or newer) ---
if [ -d "$HOME/.local/opt/curl" ]; then
    env_prepend CPATH "$HOME/.local/opt/curl/include"
    env_prepend LIBRARY_PATH "$HOME/.local/opt/curl/lib"
    env_prepend LD_LIBRARY_PATH "$HOME/.local/opt/curl/lib"
fi

# --- Aliases ---
alias slm='fish -C "source \"$HOME/.config/fish/config_slm.fish\""'
