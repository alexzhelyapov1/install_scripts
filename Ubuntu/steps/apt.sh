#!/bin/bash
# Adds third-party apt repositories and installs requirements/apt.txt.

set -euo pipefail

cd $(dirname "$0")/..
source lib/common.sh

# --- Variables ---
APT_LIST="requirements/apt.txt"
SOURCES_DIR="/etc/apt/sources.list.d"
SOURCES_CHANGED=0

# Downloads a repository key once. Binary keys (.gpg) are dearmored, .asc keys are stored as is.
add_key() {
    local url="$1"
    local path="$2"

    if [ -f "$path" ]; then
        log_info "Key exists: $path"
        return 0
    fi
    sudo mkdir -p "$(dirname "$path")"
    if [[ "$path" == *.gpg ]]; then
        curl -fsSL "$url" | sudo gpg --dearmor -o "$path"
    else
        curl -fsSL "$url" | sudo tee "$path" > /dev/null
    fi
    sudo chmod a+r "$path"
    mark_changed "Added key $path"
    SOURCES_CHANGED=1
}

# Writes a deb822 .sources file from stdin if its content differs.
add_sources() {
    local path="$SOURCES_DIR/$1"
    local content
    content="$(cat)"

    if [ -f "$path" ] && [ "$(cat "$path")" == "$content" ]; then
        log_info "Repository is up to date: $path"
        return 0
    fi
    printf '%s\n' "$content" | write_file "$path" sudo
    SOURCES_CHANGED=1
}

# --- 1. Base tools for adding repositories ---
log_info "Updating package lists..."
sudo apt-get update -y
apt_install ca-certificates curl gnupg

# --- 2. Third-party repositories ---
# Docker: https://docs.docker.com/engine/install/ubuntu/
add_key "https://download.docker.com/linux/ubuntu/gpg" "/etc/apt/keyrings/docker.asc"
add_sources docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: noble
Components: stable
Architectures: amd64
Signed-By: /etc/apt/keyrings/docker.asc
EOF

# Google Chrome. The package maintains this exact file itself, so the content matches what it writes.
add_key "https://dl.google.com/linux/linux_signing_key.pub" "/usr/share/keyrings/google-chrome.gpg"
add_sources google-chrome.sources <<EOF
### THIS FILE IS AUTOMATICALLY CONFIGURED ###
# Changes to this file will not be preserved.
# This file will not be recreated if removed.
X-Repolib-Name: Google Chrome
Types: deb
URIs: https://dl.google.com/linux/chrome-stable/deb/
Suites: stable
Components: main
Architectures: amd64
Signed-By: /usr/share/keyrings/google-chrome.gpg
EOF

# LLVM: https://apt.llvm.org
add_key "https://apt.llvm.org/llvm-snapshot.gpg.key" "/etc/apt/keyrings/llvm.asc"
add_sources llvm.sources <<EOF
Types: deb
URIs: https://apt.llvm.org/noble/
Suites: llvm-toolchain-noble-22
Components: main
Signed-By: /etc/apt/keyrings/llvm.asc
EOF

# VS Code: https://code.visualstudio.com/docs/setup/linux. Same paths as the package uses, so it doesn't add a second copy.
add_key "https://packages.microsoft.com/keys/microsoft.asc" "/usr/share/keyrings/microsoft.gpg"
add_sources vscode.sources <<EOF
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64,arm64,armhf
Signed-By: /usr/share/keyrings/microsoft.gpg
EOF

if [ "$SOURCES_CHANGED" -eq 1 ]; then
    log_info "Repositories changed, updating package lists..."
    sudo apt-get update -y
fi

# --- 3. Packages ---
mapfile -t PACKAGES < <(read_list "$APT_LIST")
apt_install "${PACKAGES[@]}"

# --- 4. clang points at clang-22 ---
# Builds call plain clang and clang++
if [ "$(update-alternatives --query clang 2>/dev/null | awk '$1 == "Value:" {print $2}')" == "/usr/bin/clang-22" ] \
    && grep -q "^ clang++ /usr/bin/clang++$" <<< "$(update-alternatives --query clang)"; then
    log_info "clang and clang++ point at clang-22"
else
    sudo update-alternatives --install /usr/bin/clang clang /usr/bin/clang-22 100 \
        --slave /usr/bin/clang++ clang++ /usr/bin/clang++-22
    mark_changed "Set clang and clang++ alternatives to clang-22"
fi
