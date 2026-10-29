# Ubuntu

Turns a fresh Ubuntu 24.04 (user `alex`) into the working environment. Every step is idempotent: run it again after a failure or to sync a machine with the repository.

### Before the first run
- ssh key in `~/.ssh` (GitHub repositories are cloned over ssh), `git` installed.
- Clone this repository: `git clone git@github.com:alexzhelyapov1/install_scripts.git ~/install_scripts`
- Create the machine-specific settings and check the values:
```bash
cp dotfiles/bash/env.local.example dotfiles/bash/env.local
```
- Choose where `/mnt/storage` comes from in `storage.conf` (default: bind mount of `~/.storage`).

### Run
```bash
./install.sh                # all steps
./install.sh shell vscode   # only the listed steps
```
Run as the regular user, the script calls `sudo` itself. At the end it prints a report: status of every step and the manual steps left. Full log: `~/.cache/install_scripts/`.

On the first gitea clone git asks for the login and an access token. They are kept in GNOME Keyring.

### Steps
| Step | What it does |
|------|--------------|
| `storage`  | `/mnt/storage` (bind mount or disk, `storage.conf`), `/mnt/storage/gravilink/{core,.bin}` |
| `apt`      | Docker, Chrome, LLVM, VS Code repositories, `requirements/apt.txt` |
| `snap`     | `requirements/snap.txt` (only what apt doesn't have) |
| `tools`    | uv, nvm + Node, `requirements/npm.txt`, emsdk, curl from source |
| `shell`    | `~/.bashrc` block that sources `dotfiles/bash/env.sh`, fish config links |
| `vscode`   | settings links, `requirements/vscode.txt` |
| `gnome`    | keyboard layouts, Alt+Shift switching |
| `git`      | identity (work email under `/mnt/storage/gravilink`), gitea credentials helper |
| `repos`    | `requirements/repos.txt` |
| `services` | sendme-bot and time-logger: venvs, cron, `.bin` links, systemd user services |
| `agents`   | `wsg setup` from work-setup-gravilink, agents-setup: MCP server, skills, Codex agents, MPL language server |
| `system`   | docker group, GRUB timeout on dual boot |

### Keep the repository up to date
- Configs (`env.sh`, fish, VS Code settings) are links into the repository: edit them in place, then commit.
- `inst <package>` (bash and fish) installs an apt package and appends it to `requirements/apt.txt`.
- `./install.sh diff` shows apt, snap, npm packages, VS Code extensions and repositories that differ from the lists.

# Notes

### Change /bin/sh to bash
```
sudo dpkg-reconfigure dash   # select <no>
```

### Virtual box commands
- Change folder owner: `sudo chown $USER:$USER /path/to/file`
