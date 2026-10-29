#!/bin/bash
# Links Claude Code and Codex memory and configs into work-setup-gravilink (its wsg tool).

set -euo pipefail

cd $(dirname "$0")/..
source lib/common.sh
load_env_local

# --- Variables ---
WSG="$WORK_SETUP_DIR/bin/wsg"

if [ ! -x "$WSG" ]; then
    log_error "$WSG not found (the repos step clones $WORK_SETUP_DIR)."
fi

# --- 1. Links ---
# wsg setup makes a backup on every run, so it runs only when wsg status reports something to repair.
# It refuses to run while claude or codex sessions are open.
WSG_STATUS="$("$WSG" status)"
if grep -qx "  nothing to do" <<< "$WSG_STATUS"; then
    log_info "Agent links are up to date"
else
    "$WSG" setup || log_error "wsg setup failed. Close claude and codex sessions and run: ./install.sh agents"
    mark_changed "Linked agent memory and configs into $WORK_SETUP_DIR"
    report_todo "Review $WORK_SETUP_DIR after wsg setup (git status, conflicts/) and commit"
fi

# --- 2. Status ---
"$WSG" status
if [ -n "$(ls -A "$WORK_SETUP_DIR/conflicts" 2>/dev/null)" ]; then
    report_todo "Resolve files in $WORK_SETUP_DIR/conflicts"
fi
