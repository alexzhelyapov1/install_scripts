#!/bin/bash

cd $(dirname "$0")
APT_REQUIREMENTS="requirements_apt.txt"
PIP_REQUIREMENTS="requirements_pip.txt"

if [ ! -f "$APT_REQUIREMENTS" ] || [ ! -f "$PIP_REQUIREMENTS" ]; then
    echo "Can't find requirements files"
    exit 1
fi

if ! command -v lsb_release >/dev/null || [ "$(lsb_release -is)" != "Ubuntu" ]; then
    echo "[ERROR] This script for Ubuntu OS only."
    exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root: sudo $0"
    exit 1
fi

# Setup keyboard
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'ru'), ('xkb', 'us+colemak')]"
gsettings set org.gnome.desktop.input-sources xkb-options "['grp:alt_shift_toggle']"

# For python
echo 'export PATH="$PATH:/home/alex/.local/bin"' >> ~/.bashrc

# Update and apt install
apt update -y
grep -vE '^#|^$' "$APT_REQUIREMENTS" | xargs apt install -y

# Install pip packages
python3 -m venv ~/.venv
source ~/.venv/bin/activate
pip install --upgrade pip
python3 -m pip install -r "$PIP_REQUIREMENTS"
