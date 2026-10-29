#!/bin/bash
# Clones requirements/repos.txt. Existing repositories are left as they are.

set -euo pipefail

cd $(dirname "$0")/..
source lib/common.sh
load_env_local

# --- Variables ---
REPOS_LIST="requirements/repos.txt"
EXPANDED_VARIABLES='$HOME $GRAVILINK_DIR $WORK_SETUP_DIR $SENDME_BOT_DIR $TIME_LOGGER_DIR'
FAILED=()

# --- 1. Clone ---
while read -r url dir; do
    if [ -z "$dir" ]; then
        log_warning "No directory for $url in $REPOS_LIST"
        FAILED+=("$url")
        continue
    fi

    if [ -d "$dir/.git" ]; then
        current_url="$(git -C "$dir" remote get-url origin 2>/dev/null || true)"
        if [ "$current_url" != "$url" ]; then
            log_warning "$dir has origin '$current_url', expected '$url'"
        else
            log_info "Repository exists: $dir"
        fi
        continue
    fi

    if [ -e "$dir" ] && [ -n "$(ls -A "$dir")" ]; then
        log_warning "$dir exists, is not empty and is not a git repository"
        FAILED+=("$dir")
        continue
    fi

    mkdir -p "$(dirname "$dir")"
    log_info "Cloning $url into $dir"
    # stdin from /dev/null: ssh must not eat the list. Credential prompts go to the terminal directly.
    if git clone "$url" "$dir" < /dev/null; then
        mark_changed "Cloned $dir"
    else
        FAILED+=("$dir")
    fi
done < <(read_list "$REPOS_LIST" | envsubst "$EXPANDED_VARIABLES")

if [ ${#FAILED[@]} -gt 0 ]; then
    log_error "Not cloned:\n$(printf '  %s\n' "${FAILED[@]}")"
fi
