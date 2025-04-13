#!/bin/bash

cd $(dirname "$0")
APT_REQUIREMENTS="requirements_apt.txt"
PIP_REQUIREMENTS="requirements_pip.txt"

if [ ! -f "$APT_REQUIREMENTS" ] || [ ! -f "$PIP_REQUIREMENTS" ]; then
    echo "Can't find requirements files"
    exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root: sudo $0"
    exit 1
fi

# Update and apt install
apt update -y
grep -vE '^#|^$' "$APT_REQUIREMENTS" | xargs apt install -y

# Install pip packages
python3 -m venv ~/.venv
source ~/.venv/bin/activate
pip install --upgrade pip
python3 -m pip install -r "$PIP_REQUIREMENTS"