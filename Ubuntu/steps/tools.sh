#!/bin/bash
# Installs tools that are not available in apt or snap: uv, nvm + Node, global npm packages, emsdk, curl.

set -euo pipefail

cd $(dirname "$0")/..
source lib/common.sh

# --- Variables ---
LOCAL_BIN="$HOME/.local/bin"
NVM_VERSION="v0.40.5"
NODE_MAJOR="24"
NPM_LIST="requirements/npm.txt"
EMSDK_DIR="$HOME/emsdk"
EMSDK_VERSION="6.0.4"
# apt has only curl 8.5, native builds need 8.15 or newer
CURL_VERSION="8.23.0"
CURL_PREFIX="$HOME/.local/opt/curl-$CURL_VERSION"
CURL_LINK="$HOME/.local/opt/curl"

# --- 1. uv ---
if [ -x "$LOCAL_BIN/uv" ]; then
    log_info "uv is installed: $("$LOCAL_BIN/uv" --version)"
else
    log_info "Installing uv..."
    # UV_NO_MODIFY_PATH: PATH is managed by dotfiles/bash/env.sh
    curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh
    mark_changed "Installed uv"
fi

# --- 2. nvm and Node ---
if [ -s "$HOME/.nvm/nvm.sh" ]; then
    log_info "nvm is installed"
else
    log_info "Installing nvm $NVM_VERSION..."
    # PROFILE=/dev/null: nvm is loaded by dotfiles/bash/env.sh, the installer must not edit .bashrc
    curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh" | PROFILE=/dev/null bash
    mark_changed "Installed nvm $NVM_VERSION"
fi

# nvm.sh is not compatible with 'set -u'
set +u
source "$HOME/.nvm/nvm.sh"
if nvm ls "$NODE_MAJOR" >/dev/null 2>&1; then
    log_info "Node $NODE_MAJOR is installed: $(nvm version "$NODE_MAJOR")"
else
    log_info "Installing Node $NODE_MAJOR..."
    nvm install "$NODE_MAJOR"
    mark_changed "Installed Node $(nvm version "$NODE_MAJOR")"
fi
if [ "$(nvm version default)" != "$(nvm version "$NODE_MAJOR")" ]; then
    nvm alias default "$NODE_MAJOR"
    mark_changed "Set default Node to $NODE_MAJOR"
fi
nvm use default >/dev/null
set -u

# --- 3. Global npm packages ---
while read -r package; do
    if npm ls -g --depth=0 "$package" >/dev/null 2>&1; then
        log_info "npm package is installed: $package"
    else
        log_info "Installing npm package: $package"
        npm install -g "$package"
        mark_changed "Installed npm package $package"
    fi
done < <(read_list "$NPM_LIST")

# --- 4. emsdk (WebAssembly toolchain for lab-engine web builds) ---
if [ ! -d "$EMSDK_DIR/.git" ]; then
    git clone https://github.com/emscripten-core/emsdk.git "$EMSDK_DIR"
    mark_changed "Cloned emsdk to $EMSDK_DIR"
fi
if [ -x "$EMSDK_DIR/emsdk" ] && grep -qE "^\s+$EMSDK_VERSION\s+INSTALLED" <<< "$("$EMSDK_DIR/emsdk" list 2>/dev/null)"; then
    log_info "emsdk $EMSDK_VERSION is installed"
else
    log_info "Installing emsdk $EMSDK_VERSION..."
    (cd "$EMSDK_DIR" && git pull --ff-only && ./emsdk install "$EMSDK_VERSION" && ./emsdk activate "$EMSDK_VERSION")
    mark_changed "Installed and activated emsdk $EMSDK_VERSION"
fi

# --- 5. curl from source ---
if [ -x "$CURL_PREFIX/bin/curl" ] && grep -qF "curl $CURL_VERSION " <<< "$("$CURL_PREFIX/bin/curl" --version)"; then
    log_info "curl $CURL_VERSION is installed in $CURL_PREFIX"
else
    log_info "Building curl $CURL_VERSION..."
    BUILD_DIR="$(mktemp -d)"
    curl -fsSL "https://curl.se/download/curl-$CURL_VERSION.tar.xz" | tar -xJ -C "$BUILD_DIR" --strip-components=1
    (
        cd "$BUILD_DIR"
        ./configure --prefix="$CURL_PREFIX" --libdir="$CURL_PREFIX/lib" --with-openssl --enable-websockets --enable-shared --disable-static
        make -j"$(nproc)"
        make install
    )
    rm -rf "$BUILD_DIR"
    mark_changed "Built curl $CURL_VERSION into $CURL_PREFIX"
fi
# Stable path for env.sh, so a version bump doesn't need edits there
link_config "$CURL_PREFIX" "$CURL_LINK"
