#!/bin/bash
# Git identity (personal by default, work inside the work directory) and gitea credentials in GNOME Keyring.

set -euo pipefail

cd $(dirname "$0")/..
source lib/common.sh
load_env_local

# --- Variables ---
GIT_NAME="Aleksey Zhelyapov"
PERSONAL_EMAIL="alexzhelyapov1@mail.ru"
WORK_EMAIL="Aleksey.Zhelyapov@gravilink.com"
WORK_GITCONFIG="$HOME/.gitconfig-gravilink"
GITEA_URL="https://gitea.gravilink.org"
LIBSECRET_DIR="/usr/share/doc/git/contrib/credential/libsecret"
LIBSECRET_HELPER="$LIBSECRET_DIR/git-credential-libsecret"

# Sets a git config key in a file only if the value differs.
git_config_ensure() {
    local file="$1"
    local key="$2"
    local value="$3"

    if [ "$(git config --file "$file" --get "$key" || true)" == "$value" ]; then
        log_info "git config $key is up to date in $file"
        return 0
    fi
    git config --file "$file" "$key" "$value"
    mark_changed "Set git config $key = $value in $file"
}

# --- 1. Identity ---
git_config_ensure "$HOME/.gitconfig" user.name "$GIT_NAME"
git_config_ensure "$HOME/.gitconfig" user.email "$PERSONAL_EMAIL"
git_config_ensure "$HOME/.gitconfig" core.editor vim

# Work email for every repository under the work directory.
# Both the path and its real path are listed, because /mnt/storage may be a symlink.
git_config_ensure "$WORK_GITCONFIG" user.email "$WORK_EMAIL"
for dir in "$GRAVILINK_DIR" "$(realpath -m "$GRAVILINK_DIR")"; do
    git_config_ensure "$HOME/.gitconfig" "includeIf.gitdir:$dir/.path" "$WORK_GITCONFIG"
done

# --- 2. gitea credentials ---
# gitea is used over https. git asks for the login and token on the first clone and libsecret keeps them in GNOME Keyring.
if [ -x "$LIBSECRET_HELPER" ]; then
    log_info "git-credential-libsecret is built"
else
    if [ ! -f "$LIBSECRET_DIR/Makefile" ]; then
        log_error "Can't find $LIBSECRET_DIR/Makefile (it comes with the git package)."
    fi
    log_info "Building git-credential-libsecret..."
    sudo make -C "$LIBSECRET_DIR"
    mark_changed "Built $LIBSECRET_HELPER"
fi
git_config_ensure "$HOME/.gitconfig" "credential.$GITEA_URL.helper" "$LIBSECRET_HELPER"
