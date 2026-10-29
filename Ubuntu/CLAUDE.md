# Ubuntu setup

This folder is the main entry point that turns a fresh Ubuntu 24.04 install into the usual working environment. It installs packages and tools, deploys shell configs, writes environment variables, clones the other repositories and hands off to their own setup tools (for example `wsg setup` of work-setup-gravilink). Other configuration repositories are managed from here, not the other way around.

The version is deliberately minimal and grows over time. Postponed items are in `TODO.md`.

## Scope

- Work only inside `Ubuntu/`. Do not touch `Windows/` or files outside this folder unless explicitly asked.
- Target system: Ubuntu 24.04 only. User name is always `alex`, home is always `/home/alex`. Hardcoding these is fine.
- The task here is environment installation and configuration. No project-specific work (builds of other repositories, work scripts).
- Nothing Python is installed into the global environment. Python tools go through `uv`, project dependencies live in project venvs.
- Secrets (tokens, passwords, VPN configs, private keys) never go into this repository.
- Don't run `install.sh` or its steps on the current PC unless asked: it is set up by hand and is not migrated yet.

## Layout

| Path | Purpose |
|------|---------|
| `install.sh` | Orchestrator: checks, sudo, runs `steps/*.sh`, final report. `./install.sh diff` runs `diff.sh` |
| `steps/<name>.sh` | One step each. Runs as its own process, so a failed step doesn't stop the others |
| `lib/common.sh` | Logging, report and idempotency helpers shared by all scripts |
| `requirements/*.txt` | Lists: apt, snap, npm, VS Code extensions, repositories |
| `dotfiles/` | Configs deployed as symlinks (fish, VS Code) or sourced (`bash/env.sh`) |
| `dotfiles/bash/env.local` | Machine-specific variables, not tracked. Template: `env.local.example` |
| `templates/` | Files generated with machine paths (systemd units) or linked (autostart) |
| `storage.conf` | Where `/mnt/storage` comes from |

## Main rules

- **Idempotency.** Every step can run any number of times, after a failure or on a configured machine, and must not duplicate or clutter anything. Check before acting, skip with a log line when the state is already right. Use the helpers from `lib/common.sh`: `apt_install`, `link_config`, `write_file`, `write_marker_block`.
- **PATH and other path variables** are only extended through `env_prepend` in `dotfiles/bash/env.sh`, which skips a directory that is already there. Never `export PATH="...:$PATH"` directly, never append to `~/.bashrc` from tools' installers (pass their "don't modify profile" options).
- **One place to edit.** Anything the user may change on the machine lives in this repository and is linked or sourced from its usual location, so the change shows up in `git diff` here. `~/.bashrc` gets only one marker block that sources `env.sh`.
- **Machine-specific values** (paths that differ between machines) go to `env.local`, never into tracked files. Add new variables to `env.local.example` as well.
- **Source priority:** apt first (including third-party apt repositories), then snap, then anything else (official installers, builds from source).
- **Report.** A step calls `mark_changed` for every change (the step is then OK, otherwise UNCHANGED) and `report_todo` for what the user has to do by hand. Directories are created when missing.
- **Pipes with `grep -q`** are written as `grep -q ... <<< "$(cmd)"`: with `pipefail` an early exit of `grep` can fail the pipe.

## Style of scripts

- Bash only, `#!/bin/bash` shebang, `set -euo pipefail` at the top.
- First line of logic: `cd $(dirname "$0")` (steps: `cd $(dirname "$0")/..`), then `source lib/common.sh`, and `load_env_local` if the step needs machine paths.
- Logging through `log_info`, `log_ok`, `log_warning`, `log_error` (`log_error` prints to stderr and exits). Messages are in English.
- Sections are separated by numbered comment headers: `# --- 1. Packages ---`. Helper groups use the same form without a number: `# --- Logging functions ---`.
- Global variables in `UPPER_SNAKE_CASE`, defined in a `# --- Variables ---` section near the top. Locals in functions use `local`.
- Validate early and fail with a clear message.
- Scripts run as `alex` and call `sudo` only for commands that need it, so `~`, `gsettings` and user files belong to `alex`, not `root`.
- `apt-get` with `-y` and `DEBIAN_FRONTEND=noninteractive` for unattended installs.
- Script names use kebab-case. A new step is added to `STEPS` in `install.sh` and to the table in `README.md`.

## Lists

- Plain text, one item per line. `#` starts a comment line (a note or a commented-out item), empty lines are allowed. Scripts read them with `read_list`.
- `snap.txt` allows snap flags after the name. `repos.txt` is `<url> <directory>`, variables from `env.local` are expanded in the directory.

## Editing user files

- Never overwrite user files wholesale. `~/.bashrc` gets a block between `# <MARKER> BEGIN` and `# <MARKER> END` lines, framed by separators. `write_marker_block` replaces the block in place when its content changes.
- Separator lines are `# ` followed by dashes up to column 120. Fish configs use the same separators.
- Anything that has to be replaced by a link is moved to `~/.cache/install_scripts/backup/` first.

## README

`README.md` is a short list of `###` sections, each with a one-line explanation and the command to run. Manual steps that cannot be scripted are documented there in the same form.
