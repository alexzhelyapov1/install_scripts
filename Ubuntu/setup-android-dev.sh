#!/bin/bash

set -euo pipefail

# --- Colors for logs ---
COLOR_RESET='\033[0m'
COLOR_ORANGE='\033[0;33m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_BLUE='\033[0;34m'

# --- Logging functions ---
log_info() {
    echo -e "${COLOR_BLUE}[INFO] $1${COLOR_RESET}"
}

log_warning() {
    echo -e "${COLOR_ORANGE}[WARNING] $1${COLOR_RESET}"
}

log_error() {
    echo -e "${COLOR_RED}[ERROR] $1${COLOR_RESET}" >&2
    exit 1
}

# --- 1. Argument check ---
if [ "$#" -ne 1 ]; then
    log_error "Invalid number of arguments. Usage: $0 <android-studio.tar.gz>\nPlease download it from https://developer.android.com/studio."
fi

TAR_GZ_PATH="$1"

if [ ! -f "$TAR_GZ_PATH" ]; then
    log_error "File '$TAR_GZ_PATH' not found."
fi

if [[ "$TAR_GZ_PATH" != *.tar.gz ]]; then
    log_error "File '$TAR_GZ_PATH' does not look like a .tar.gz archive."
fi

# --- 2. Sudo check ---
if [ "$EUID" -ne 0 ]; then
  log_error "This script must be run as root (sudo)."
fi

# --- Variables ---
ANDROID_STUDIO_INSTALL_DIR="/opt/android-studio"
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "user")}"

log_info "Starting Android Studio setup..."

# --- 3. Create directory and extract Android Studio ---
log_info "Creating directory $ANDROID_STUDIO_INSTALL_DIR..."
mkdir -p "$ANDROID_STUDIO_INSTALL_DIR" || log_error "Failed to create directory $ANDROID_STUDIO_INSTALL_DIR."

if [ "$(ls -A $ANDROID_STUDIO_INSTALL_DIR)" ]; then
   log_error "Directory $ANDROID_STUDIO_INSTALL_DIR is not empty. Existing files may be overwritten."
fi

log_info "Extracting archive $TAR_GZ_PATH to $ANDROID_STUDIO_INSTALL_DIR..."
if tar -xzvf "$TAR_GZ_PATH" -C "$ANDROID_STUDIO_INSTALL_DIR" --strip-components=1; then
    log_info "Archive extracted successfully."
else
    log_error "Failed to extract archive. Ensure the archive is valid and not corrupted."
fi

# --- 4. Check and install OpenJDK-21 ---
JDK_PACKAGE_NAME="openjdk-21-jdk"
log_info "Checking for $JDK_PACKAGE_NAME..."

if dpkg -s "$JDK_PACKAGE_NAME" &> /dev/null; then
    log_info "$JDK_PACKAGE_NAME is already installed."
else
    log_info "$JDK_PACKAGE_NAME not found. Starting installation..."
    log_info "Updating package lists (apt update)..."
    apt-get update -y || log_error "Failed to update package lists."

    log_info "Upgrading installed packages (apt upgrade)..."
    if ! DEBIAN_FRONTEND=noninteractive apt-get upgrade -y; then
        log_warning "Issues encountered during 'apt upgrade'. This may not be critical."
    fi

    log_info "Installing $JDK_PACKAGE_NAME..."
    if DEBIAN_FRONTEND=noninteractive apt-get install -y "$JDK_PACKAGE_NAME"; then
        log_info "$JDK_PACKAGE_NAME installed successfully."
    else
        log_error "Failed to install $JDK_PACKAGE_NAME."
    fi
fi

# --- 5. Check and configure KVM ---
log_info "Checking and configuring KVM..."

if ! egrep -q -c '(vmx|svm)' /proc/cpuinfo; then
    log_warning "Your CPU does not support hardware virtualization (VT-x or AMD-V)."
    log_warning "The Android Emulator will run very slowly or not at all. KVM will not be installed."
else
    log_info "CPU supports hardware virtualization."
    KVM_PACKAGES="qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils cpu-checker"

    if ! command -v kvm-ok &> /dev/null; then
        log_info "Installing cpu-checker (for kvm-ok)..."
        if ! DEBIAN_FRONTEND=noninteractive apt-get install -y cpu-checker; then
            log_warning "Failed to install cpu-checker. KVM check might be inaccurate."
        fi
    fi

    KVM_OK_OUTPUT=$(kvm-ok 2>&1 || true)

    if echo "$KVM_OK_OUTPUT" | grep -q "KVM acceleration can be used"; then
        log_info "KVM is already configured and usable."
        if ! groups "$REAL_USER" | grep -q '\bkvm\b'; then
            log_info "Adding user $REAL_USER to kvm group..."
            if usermod -aG kvm "$REAL_USER"; then
                log_info "User $REAL_USER added to kvm group. A logout/reboot is required for changes to take effect."
            else
                log_warning "Failed to add user $REAL_USER to kvm group."
            fi
        fi
    elif echo "$KVM_OK_OUTPUT" | grep -q "INFO: Your CPU supports KVM extensions" && \
         echo "$KVM_OK_OUTPUT" | grep -q "KVM acceleration can NOT be used"; then

        log_info "KVM is supported by CPU but not active. Attempting installation and configuration..."
        log_info "Installing KVM packages: $KVM_PACKAGES..."
        if DEBIAN_FRONTEND=noninteractive apt-get install -y $KVM_PACKAGES; then
            log_info "KVM packages installed successfully."
        else
            log_error "Failed to install KVM packages."
        fi

        log_info "Adding user $REAL_USER to kvm group..."
        if usermod -aG kvm "$REAL_USER"; then
            log_info "User $REAL_USER added to kvm group."
            log_info "IMPORTANT: You need to log out and log back in, or reboot, for group membership changes to take effect for $REAL_USER."
        else
            log_warning "Failed to add user $REAL_USER to kvm group."
        fi

        if ! systemctl is-active --quiet libvirtd; then
            log_info "libvirtd service is not active. Attempting to start..."
            if systemctl start libvirtd && systemctl enable libvirtd; then
                 log_info "libvirtd service started and enabled successfully."
            else
                 log_warning "Failed to start or enable libvirtd service. Check manually: sudo systemctl status libvirtd"
            fi
        fi

        log_info "Re-checking with kvm-ok..."
        sleep 2
        KVM_OK_RECHECK_OUTPUT=$(kvm-ok 2>&1 || true)
        if echo "$KVM_OK_RECHECK_OUTPUT" | grep -q "KVM acceleration can be used"; then
            log_info "${COLOR_GREEN}KVM configured successfully!${COLOR_RESET} Remember to re-login if the user was added to the group."
        else
            log_error "Failed to configure KVM after package installation.\nkvm-ok output:\n$KVM_OK_RECHECK_OUTPUT\nVirtualization might be disabled in BIOS/UEFI or other issues occurred. Check kvm-ok output and system logs."
        fi
    else
        log_warning "kvm-ok reported an issue. Output:\n$KVM_OK_OUTPUT"
        log_warning "Check if virtualization (VT-x/AMD-V) is enabled in your computer's BIOS/UEFI."
    fi
fi

# --- Completion ---
log_info "${COLOR_GREEN}Android Studio and dependencies setup completed!${COLOR_RESET}"
log_info "You can launch Android Studio using: $ANDROID_STUDIO_INSTALL_DIR/bin/studio.sh"
log_info "It is recommended to create a desktop entry via Android Studio menu: Tools -> Create Desktop Entry..."
log_info "If user $REAL_USER was added to the 'kvm' group, a logout/reboot is required for KVM accelerated emulator to work correctly."

exit 0