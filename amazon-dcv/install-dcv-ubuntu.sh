#!/bin/bash

# Amazon DCV Server Installation Script for Ubuntu x86_64
# Based on AWS Documentation: https://docs.aws.amazon.com/dcv/latest/adminguide/setting-up-installing-linux-server.html
# 
# This script installs Amazon DCV Server on Ubuntu 20.04/22.04/24.04 (x86_64)
# Supports both basic installation and optional components
# Includes desktop environment installation and screensaver/lock screen configuration

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   error "This script should not be run as root. Please run as a regular user with sudo privileges."
fi

# Check if user has sudo privileges
if ! sudo -n true 2>/dev/null; then
    error "This script requires sudo privileges. Please ensure your user can run sudo commands."
fi

# Detect Ubuntu version
UBUNTU_VERSION=$(lsb_release -rs)
UBUNTU_CODENAME=$(lsb_release -cs)

log "Detected Ubuntu version: $UBUNTU_VERSION ($UBUNTU_CODENAME)"

# Determine the correct package version based on Ubuntu release
case "$UBUNTU_VERSION" in
    "20.04")
        PACKAGE_VERSION="ubuntu2004"
        ;;
    "22.04")
        PACKAGE_VERSION="ubuntu2204"
        ;;
    "24.04")
        PACKAGE_VERSION="ubuntu2404"
        ;;
    *)
        error "Unsupported Ubuntu version: $UBUNTU_VERSION. Supported versions: 20.04, 22.04, 24.04"
        ;;
esac

# Architecture detection
ARCH=$(uname -m)
case "$ARCH" in
    "x86_64")
        DCV_ARCH="x86_64"
        DEB_ARCH="amd64"
        ;;
    "aarch64")
        DCV_ARCH="aarch64"
        DEB_ARCH="arm64"
        ;;
    *)
        error "Unsupported architecture: $ARCH. Supported architectures: x86_64, aarch64"
        ;;
esac

log "Architecture: $ARCH (DCV: $DCV_ARCH, DEB: $DEB_ARCH)"

# Configuration options
INSTALL_DESKTOP=${INSTALL_DESKTOP:-true}
DESKTOP_ENVIRONMENT=${DESKTOP_ENVIRONMENT:-"ubuntu-desktop-minimal"}
INSTALL_WEB_VIEWER=${INSTALL_WEB_VIEWER:-true}
INSTALL_VIRTUAL_SESSIONS=${INSTALL_VIRTUAL_SESSIONS:-true}
INSTALL_GPU_SUPPORT=${INSTALL_GPU_SUPPORT:-false}
INSTALL_EXTERNAL_AUTH=${INSTALL_EXTERNAL_AUTH:-false}
INSTALL_USB_REMOTIZATION=${INSTALL_USB_REMOTIZATION:-false}
INSTALL_PULSEAUDIO=${INSTALL_PULSEAUDIO:-true}
AUTO_START_SERVICE=${AUTO_START_SERVICE:-true}
DISABLE_SCREENSAVER=${DISABLE_SCREENSAVER:-true}
DISABLE_LOCK_SCREEN=${DISABLE_LOCK_SCREEN:-true}

# DCV version (using latest links)
DCV_BASE_URL="https://d1uj6qtbmh3dt5.cloudfront.net"
DCV_PACKAGE_NAME="nice-dcv-${PACKAGE_VERSION}-${DCV_ARCH}.tgz"
DCV_DOWNLOAD_URL="${DCV_BASE_URL}/${DCV_PACKAGE_NAME}"

# Temporary directory for downloads
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

log "Starting Amazon DCV Server installation..."
log "Temporary directory: $TEMP_DIR"

# Update system packages
log "Updating system packages..."
sudo apt update

# Install required dependencies
log "Installing required dependencies..."
sudo apt install -y wget gpg tar

# Download and import GPG key
log "Downloading and importing Amazon DCV GPG key..."
cd "$TEMP_DIR"
wget -q https://d1uj6qtbmh3dt5.cloudfront.net/NICE-GPG-KEY
gpg --import NICE-GPG-KEY

# Download DCV packages
log "Downloading Amazon DCV packages..."
wget "$DCV_DOWNLOAD_URL"

# Extract packages
log "Extracting DCV packages..."
tar -xzf "$DCV_PACKAGE_NAME"
cd "nice-dcv-"*

# Install core DCV server
log "Installing Amazon DCV Server..."
sudo apt install -y "./nice-dcv-server_"*"_${DEB_ARCH}.${PACKAGE_VERSION}.deb"

# Add dcv user to video group
log "Adding dcv user to video group..."
sudo usermod -aG video dcv

# Install optional components
if [[ "$INSTALL_WEB_VIEWER" == "true" ]]; then
    log "Installing DCV Web Viewer..."
    sudo apt install -y "./nice-dcv-web-viewer_"*"_${DEB_ARCH}.${PACKAGE_VERSION}.deb"
fi

if [[ "$INSTALL_VIRTUAL_SESSIONS" == "true" ]]; then
    log "Installing DCV Virtual Sessions (nice-xdcv)..."
    sudo apt install -y "./nice-xdcv_"*"_${DEB_ARCH}.${PACKAGE_VERSION}.deb"
fi

if [[ "$INSTALL_GPU_SUPPORT" == "true" && "$DCV_ARCH" == "x86_64" ]]; then
    log "Installing DCV GPU support..."
    if ls ./nice-dcv-gl_* 1> /dev/null 2>&1; then
        sudo apt install -y "./nice-dcv-gl_"*"_${DEB_ARCH}.${PACKAGE_VERSION}.deb"
        
        # Install GL test package if available
        if ls ./nice-dcv-gltest_* 1> /dev/null 2>&1; then
            log "Installing DCV GL test package..."
            sudo apt install -y "./nice-dcv-gltest_"*"_${DEB_ARCH}.${PACKAGE_VERSION}.deb"
        fi
    else
        warn "GPU support packages not available for this platform"
    fi
elif [[ "$INSTALL_GPU_SUPPORT" == "true" && "$DCV_ARCH" == "aarch64" ]]; then
    warn "GPU support packages are not available for ARM64 architecture"
fi

if [[ "$INSTALL_EXTERNAL_AUTH" == "true" ]]; then
    log "Installing DCV External Authenticator..."
    sudo apt install -y "./nice-dcv-simple-external-authenticator_"*"_${DEB_ARCH}.${PACKAGE_VERSION}.deb"
fi

if [[ "$INSTALL_USB_REMOTIZATION" == "true" ]]; then
    log "Installing USB remotization support..."
    sudo apt install -y dkms
    sudo dcvusbdriverinstaller
fi

if [[ "$INSTALL_PULSEAUDIO" == "true" ]]; then
    log "Installing PulseAudio utilities for microphone support..."
    sudo apt install -y pulseaudio-utils
fi

# Configure firewall (if ufw is active)
if sudo ufw status | grep -q "Status: active"; then
    log "Configuring firewall rules for DCV..."
    sudo ufw allow 8443/tcp comment "Amazon DCV HTTPS"
    sudo ufw allow 8443/udp comment "Amazon DCV QUIC"
fi

# Start and enable DCV service
log "Starting and enabling DCV service..."
sudo systemctl start dcvserver

if [[ "$AUTO_START_SERVICE" == "true" ]]; then
    sudo systemctl enable dcvserver
    log "DCV server configured to start automatically on boot"
fi

# Check service status
if sudo systemctl is-active --quiet dcvserver; then
    log "Amazon DCV Server is running successfully!"
else
    error "Failed to start Amazon DCV Server. Check logs with: sudo journalctl -u dcvserver"
fi

# Create a simple session for the current user
log "Creating a console session for user: $USER"
sudo dcv create-session --type=console --owner="$USER" "$USER-session" || warn "Failed to create console session. You may need to create it manually."

# Display connection information
log "Installation completed successfully!"
echo
echo -e "${BLUE}=== Amazon DCV Server Installation Summary ===${NC}"
echo -e "Ubuntu Version: $UBUNTU_VERSION"
echo -e "Architecture: $ARCH"
echo -e "DCV Server: ${GREEN}Installed and Running${NC}"
echo -e "Web Viewer: $([ "$INSTALL_WEB_VIEWER" == "true" ] && echo -e "${GREEN}Installed${NC}" || echo -e "${YELLOW}Not Installed${NC}")"
echo -e "Virtual Sessions: $([ "$INSTALL_VIRTUAL_SESSIONS" == "true" ] && echo -e "${GREEN}Installed${NC}" || echo -e "${YELLOW}Not Installed${NC}")"
echo -e "GPU Support: $([ "$INSTALL_GPU_SUPPORT" == "true" ] && echo -e "${GREEN}Installed${NC}" || echo -e "${YELLOW}Not Installed${NC}")"
echo -e "Auto-start: $([ "$AUTO_START_SERVICE" == "true" ] && echo -e "${GREEN}Enabled${NC}" || echo -e "${YELLOW}Disabled${NC}")"
echo
echo -e "${BLUE}=== Connection Information ===${NC}"
echo -e "DCV Server URL: ${GREEN}https://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || hostname -I | awk '{print $1}'):8443${NC}"
echo -e "Session Name: ${GREEN}$USER-session${NC}"
echo
echo -e "${BLUE}=== Useful Commands ===${NC}"
echo -e "Check service status: ${GREEN}sudo systemctl status dcvserver${NC}"
echo -e "View service logs: ${GREEN}sudo journalctl -u dcvserver -f${NC}"
echo -e "List sessions: ${GREEN}dcv list-sessions${NC}"
echo -e "Create new session: ${GREEN}dcv create-session --type=console --owner=\$USER my-session${NC}"
echo -e "Delete session: ${GREEN}dcv close-session session-name${NC}"
echo
echo -e "${YELLOW}Note: Make sure port 8443 is open in your security group for HTTPS access.${NC}"
echo -e "${YELLOW}For QUIC protocol support, also open UDP port 8443.${NC}"

log "Amazon DCV Server installation completed!"
