#!/bin/bash
# Prepares sendme-bot and time-logger: venvs, cron, links in .bin, systemd user services, browser autostart.

set -euo pipefail

cd $(dirname "$0")/..
source lib/common.sh
load_env_local

# --- Variables ---
UV="$HOME/.local/bin/uv"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
AUTOSTART_DIR="$HOME/.config/autostart"
EXPANDED_VARIABLES='$SENDME_BOT_DIR $TIME_LOGGER_DIR'
CRON_LINE="0 12 * * * \"$TIME_LOGGER_DIR/daily_commit.sh\" >> \"$TIME_LOGGER_DIR/daily_commit.log\" 2>&1"

for dir in "$SENDME_BOT_DIR" "$TIME_LOGGER_DIR"; do
    if [ ! -d "$dir" ]; then
        log_error "$dir not found (the repos step clones it)."
    fi
done
if [ ! -x "$UV" ]; then
    log_error "uv not found (the tools step installs it)."
fi

# --- 1. Virtual environments ---
for dir in "$SENDME_BOT_DIR" "$TIME_LOGGER_DIR"; do
    if [ ! -x "$dir/venv/bin/python3" ]; then
        "$UV" venv "$dir/venv"
        mark_changed "Created $dir/venv"
    fi
    UV_OUTPUT="$("$UV" pip install --python "$dir/venv/bin/python3" -r "$dir/requirements.txt" 2>&1)"
    echo "$UV_OUTPUT"
    if grep -q "^Installed" <<< "$UV_OUTPUT"; then
        mark_changed "Installed requirements into $dir/venv"
    fi
done

# --- 2. cron: daily commit of time-logger data ---
CURRENT_CRONTAB="$(crontab -l 2>/dev/null || true)"
if grep -qxF "$CRON_LINE" <<< "$CURRENT_CRONTAB"; then
    log_info "cron entry is up to date"
else
    # An entry with another path (repository moved) is replaced, not duplicated
    { grep -vF "/daily_commit.sh" <<< "$CURRENT_CRONTAB" || true; echo "$CRON_LINE"; } | sed '/^$/d' | crontab -
    mark_changed "Set cron entry: $CRON_LINE"
fi

# --- 3. Commands in .bin ---
link_config "$SENDME_BOT_DIR/sendme" "$GRAVILINK_DIR/.bin/sendme"
link_config "$SENDME_BOT_DIR/mdsendme" "$GRAVILINK_DIR/.bin/mdsendme"

# --- 4. systemd user services ---
for template in templates/systemd/*.service; do
    envsubst "$EXPANDED_VARIABLES" < "$template" | write_file "$SYSTEMD_USER_DIR/$(basename "$template")"
done
systemctl --user daemon-reload

# sendme-bot can't start before init.py has written the bot token and chat id into .env
if [ -f "$SENDME_BOT_DIR/.env" ]; then
    SERVICES=(sendme-bot time-logger)
else
    SERVICES=(time-logger)
    report_todo "Run 'cd $SENDME_BOT_DIR && venv/bin/python3 init.py', then 'systemctl --user enable --now sendme-bot'"
fi

for service in "${SERVICES[@]}"; do
    if systemctl --user is-enabled --quiet "$service" && systemctl --user is-active --quiet "$service"; then
        log_info "Service is enabled and running: $service"
    else
        systemctl --user enable --now "$service"
        mark_changed "Enabled and started $service"
    fi
done

# --- 5. Open time-logger in the browser after login ---
# A separate autostart entry, not part of the service: a browser started from the service would be killed with it.
link_config "$UBUNTU_DIR/templates/autostart/time-logger.desktop" "$AUTOSTART_DIR/time-logger.desktop"
