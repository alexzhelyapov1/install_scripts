#!/bin/bash
# Links Claude Code and Codex memory and configs into work-setup-gravilink (its wsg tool)
# and installs the MPL toolkit from agents-setup: MCP server, skills, Codex agents, LSP.

set -euo pipefail

cd $(dirname "$0")/..
source lib/common.sh
load_env_local

# --- Variables ---
WSG="$WORK_SETUP_DIR/bin/wsg"
AGENTS_SETUP_DIR="$GRAVILINK_DIR/core/agents-setup"
MPL_TOOLS_DIR="$AGENTS_SETUP_DIR/mcp/mpl-tools"
UV="$HOME/.local/bin/uv"
CLAUDE="$HOME/.local/bin/claude"
CODEX_CONFIG="$HOME/.codex/config.toml"
MPL_LSP_SOURCE="git+https://gitea.gravilink.org/Tools/mpl-pygls-lsp.git"

if [ ! -x "$WSG" ]; then
    log_error "$WSG not found (the repos step clones $WORK_SETUP_DIR)."
fi
if [ ! -d "$AGENTS_SETUP_DIR" ]; then
    log_error "$AGENTS_SETUP_DIR not found (the repos step clones it)."
fi
if [ ! -x "$UV" ]; then
    log_error "uv not found (the tools step installs it)."
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

# --- 3. MPL MCP server ---
# Codex starts the server from this venv (codex/config.toml in work-setup-gravilink), Claude Code through 'uv run'
UV_OUTPUT="$("$UV" sync --project "$MPL_TOOLS_DIR" 2>&1)"
echo "$UV_OUTPUT"
if grep -q "^Installed" <<< "$UV_OUTPUT"; then
    mark_changed "Installed the MCP server environment in $MPL_TOOLS_DIR/.venv"
fi

if [ ! -x "$CLAUDE" ]; then
    report_todo "Install Claude Code, then run ./install.sh agents to add the mpl-tools MCP server"
elif "$CLAUDE" mcp get mpl-tools > /dev/null 2>&1; then
    log_info "Claude Code MCP server is configured: mpl-tools"
else
    "$CLAUDE" mcp add-json --scope user mpl-tools "$(cat <<EOF
{"command": "$UV", "args": ["run", "--project", "$MPL_TOOLS_DIR", "python", "$MPL_TOOLS_DIR/server.py"], "env": {"MPL_ROOT": "$GRAVILINK_DIR/core"}}
EOF
)"
    mark_changed "Added the mpl-tools MCP server to Claude Code"
fi

if ! grep -qF '[mcp_servers."mpl-tools"]' "$CODEX_CONFIG" 2>/dev/null; then
    report_todo "Add the mpl-tools MCP server to $WORK_SETUP_DIR/codex/config.toml (see $AGENTS_SETUP_DIR/SETUP.md)"
fi

# --- 4. Skills and Codex agents ---
for skill in "$AGENTS_SETUP_DIR"/skills/*/; do
    skill="${skill%/}"
    link_config "$skill" "$HOME/.agents/skills/$(basename "$skill")"
    link_config "$skill" "$HOME/.claude/skills/$(basename "$skill")"
done
for agent in "$AGENTS_SETUP_DIR"/agents/*.toml; do
    link_config "$agent" "$HOME/.codex/agents/$(basename "$agent")"
done

# --- 5. MPL language server ---
if grep -q "^mpl-pygls-lsp " <<< "$("$UV" tool list 2>/dev/null)"; then
    log_info "mpl-pygls-lsp is installed"
elif "$UV" tool install "$MPL_LSP_SOURCE" < /dev/null; then
    mark_changed "Installed mpl-pygls-lsp"
else
    report_todo "Install the MPL language server: uv tool install $MPL_LSP_SOURCE"
fi
