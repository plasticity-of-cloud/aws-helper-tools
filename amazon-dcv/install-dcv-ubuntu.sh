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
INSTALL_XDUMMY_DRIVER=${INSTALL_XDUMMY_DRIVER:-true}
INSTALL_EXTERNAL_AUTH=${INSTALL_EXTERNAL_AUTH:-false}
INSTALL_USB_REMOTIZATION=${INSTALL_USB_REMOTIZATION:-false}
INSTALL_PULSEAUDIO=${INSTALL_PULSEAUDIO:-true}
AUTO_START_SERVICE=${AUTO_START_SERVICE:-true}
AUTO_CREATE_SESSION=${AUTO_CREATE_SESSION:-true}
USE_VIRTUAL_SESSIONS=${USE_VIRTUAL_SESSIONS:-true}
DISABLE_SCREENSAVER=${DISABLE_SCREENSAVER:-true}
DISABLE_LOCK_SCREEN=${DISABLE_LOCK_SCREEN:-true}

# DCV version 2024.0 (latest as of documentation review)
DCV_VERSION="2024.0"
DCV_BUILD="19030"
DCV_BASE_URL="https://d1uj6qtbmh3dt5.cloudfront.net"

# Use Ubuntu 22.04 packages for Ubuntu 24.04 compatibility (closest supported version)
if [[ "$UBUNTU_VERSION" == "24.04" ]]; then
    PACKAGE_VERSION="ubuntu2204"
    warn "Using Ubuntu 22.04 packages for Ubuntu 24.04 (closest supported version)"
fi

DCV_PACKAGE_NAME="nice-dcv-${DCV_VERSION}-${DCV_BUILD}-${PACKAGE_VERSION}-${DCV_ARCH}.tgz"
DCV_DOWNLOAD_URL="${DCV_BASE_URL}/${DCV_VERSION}/Servers/${DCV_PACKAGE_NAME}"

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

# Install desktop environment if requested
if [[ "$INSTALL_DESKTOP" == "true" ]]; then
    log "Installing desktop environment: $DESKTOP_ENVIRONMENT"
    sudo apt install -y "$DESKTOP_ENVIRONMENT"
    
    # Fix systemd-networkd-wait-online service timeout issue on EC2
    log "Fixing systemd-networkd-wait-online service for EC2 instances..."
    sudo systemctl disable systemd-networkd-wait-online.service || warn "Could not disable systemd-networkd-wait-online.service"
    sudo systemctl mask systemd-networkd-wait-online.service || warn "Could not mask systemd-networkd-wait-online.service"
    log "Network service timeout issue fixed"
    
    # Disable Wayland for DCV compatibility
    log "Disabling Wayland for DCV compatibility..."
    if [ -f /etc/gdm3/custom.conf ]; then
        sudo cp /etc/gdm3/custom.conf /etc/gdm3/custom.conf.backup
        if grep -q "WaylandEnable" /etc/gdm3/custom.conf; then
            sudo sed -i 's/#WaylandEnable=false/WaylandEnable=false/' /etc/gdm3/custom.conf
            sudo sed -i 's/WaylandEnable=true/WaylandEnable=false/' /etc/gdm3/custom.conf
        else
            sudo sed -i '/\[daemon\]/a WaylandEnable=false' /etc/gdm3/custom.conf
        fi
        log "Wayland disabled - system will use X11 for DCV compatibility"
    else
        warn "GDM3 configuration file not found - Wayland may still be enabled"
    fi
fi

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
DCV_DIR=$(find . -maxdepth 1 -name "nice-dcv-*" -type d | head -1)
if [[ -z "$DCV_DIR" ]]; then
    log "ERROR: Could not find extracted DCV directory"
    exit 1
fi
cd "$DCV_DIR"

# Install core DCV server
log "Installing Amazon DCV Server..."
DCV_SERVER_DEB=$(find . -name "nice-dcv-server_*_${DEB_ARCH}.deb" | head -1)
if [[ -n "$DCV_SERVER_DEB" ]]; then
    sudo apt install -y "$DCV_SERVER_DEB"
else
    error "DCV Server package not found"
fi

# Add dcv user to video group
log "Adding dcv user to video group..."
sudo usermod -aG video dcv

# Install optional components
if [[ "$INSTALL_WEB_VIEWER" == "true" ]]; then
    log "Installing DCV Web Viewer..."
    DCV_WEB_DEB=$(find . -name "nice-dcv-web-viewer_*_${DEB_ARCH}.deb" | head -1)
    if [[ -n "$DCV_WEB_DEB" ]]; then
        sudo apt install -y "$DCV_WEB_DEB"
    else
        warn "DCV Web Viewer package not found"
    fi
fi

if [[ "$INSTALL_VIRTUAL_SESSIONS" == "true" ]]; then
    log "Installing DCV Virtual Sessions (nice-xdcv)..."
    DCV_XDCV_DEB=$(find . -name "nice-xdcv_*_${DEB_ARCH}.deb" | head -1)
    if [[ -n "$DCV_XDCV_DEB" ]]; then
        sudo apt install -y "$DCV_XDCV_DEB"
    else
        warn "DCV Virtual Sessions package not found"
    fi
fi

if [[ "$INSTALL_GPU_SUPPORT" == "true" && "$DCV_ARCH" == "x86_64" ]]; then
    log "Installing DCV GPU support..."
    DCV_GL_DEB=$(find . -name "nice-dcv-gl_*_${DEB_ARCH}.deb" | head -1)
    if [[ -n "$DCV_GL_DEB" ]]; then
        sudo apt install -y "$DCV_GL_DEB"
        
        # Install GL test package if available
        DCV_GLTEST_DEB=$(find . -name "nice-dcv-gltest_*_${DEB_ARCH}.deb" | head -1)
        if [[ -n "$DCV_GLTEST_DEB" ]]; then
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

# Configure desktop environment settings
if [[ "$INSTALL_DESKTOP" == "true" ]]; then
    log "Configuring desktop environment settings..."
    
    # Disable screensaver and lock screen if requested
    if [[ "$DISABLE_SCREENSAVER" == "true" || "$DISABLE_LOCK_SCREEN" == "true" ]]; then
        log "Configuring screensaver and lock screen settings for user: $USER"
        
        # Create user directories if they don't exist
        mkdir -p "/home/$USER/.config/dconf"
        
        # Configure GNOME settings to disable screensaver and lock screen
        if [[ "$DISABLE_SCREENSAVER" == "true" ]]; then
            log "Disabling screensaver..."
            sudo -u "$USER" dbus-launch gsettings set org.gnome.desktop.screensaver idle-activation-enabled false 2>/dev/null || warn "Could not disable screensaver via gsettings"
            sudo -u "$USER" dbus-launch gsettings set org.gnome.desktop.session idle-delay 0 2>/dev/null || warn "Could not set idle delay via gsettings"
        fi
        
        if [[ "$DISABLE_LOCK_SCREEN" == "true" ]]; then
            log "Disabling lock screen..."
            sudo -u "$USER" dbus-launch gsettings set org.gnome.desktop.screensaver lock-enabled false 2>/dev/null || warn "Could not disable lock screen via gsettings"
            sudo -u "$USER" dbus-launch gsettings set org.gnome.desktop.lockdown disable-lock-screen true 2>/dev/null || warn "Could not disable lock screen lockdown via gsettings"
        fi
    fi
    
    log "Desktop environment configuration completed"
fi

# Install XDummy driver for non-GPU instances (enables flexible resolution control)
if [[ "$INSTALL_XDUMMY_DRIVER" == "true" && "$INSTALL_GPU_SUPPORT" != "true" ]]; then
    log "Installing XDummy driver for flexible display resolution control..."
    sudo apt install -y xserver-xorg-video-dummy
    
    # Configure XDummy in xorg.conf
    log "Configuring XDummy driver..."
    sudo mkdir -p /etc/X11
    sudo tee /etc/X11/xorg.conf > /dev/null << 'EOF'
Section "Device"
    Identifier "DummyDevice"
    Driver "dummy"
    Option "UseEDID" "false"
    VideoRam 512000
EndSection

Section "Monitor"
    Identifier "DummyMonitor"
    HorizSync   5.0 - 1000.0
    VertRefresh 5.0 - 200.0
    Option "ReducedBlanking"
EndSection

Section "Screen"
    Identifier "DummyScreen"
    Device "DummyDevice"
    Monitor "DummyMonitor"
    DefaultDepth 24
    SubSection "Display"
        Viewport 0 0
        Depth 24
        Virtual 4096 2160
    EndSubSection
EndSection
EOF
    
    log "XDummy driver installed and configured for flexible resolution control"
fi

# Configure automatic session creation and startup
if [[ "$AUTO_CREATE_SESSION" == "true" ]]; then
    log "Configuring automatic DCV session startup..."

    # Create DCV configuration directory if it doesn't exist
    sudo mkdir -p /etc/dcv

    # Configure DCV server for automatic session creation
    log "Configuring DCV server settings..."
    sudo tee /etc/dcv/dcv.conf > /dev/null << EOF
[license]
[log]
[session-management]
virtual-session-xdcv-args="-ac -nolisten tcp -extension GLX"
create-session = true
[session-management/defaults]
[session-management/automatic-console-session]
storage-root="/home"
[display]
target-fps=25
enable-client-resize=true
max-head-resolution=(4096, 2160)
web-client-max-head-resolution=(2560, 1440)
min-head-resolution=(800, 600)
max-num-heads=2
[connectivity]
web-url-path="/dcv"
[security]
authentication="system"
EOF

    # Set proper permissions for DCV configuration
    sudo chown root:root /etc/dcv/dcv.conf
    sudo chmod 644 /etc/dcv/dcv.conf

    # Add current user to dcv group for session management
    log "Adding user $USER to dcv group..."
    sudo usermod -aG dcv "$USER"

    # Determine session type based on configuration
    if [[ "$USE_VIRTUAL_SESSIONS" == "true" && "$INSTALL_VIRTUAL_SESSIONS" == "true" ]]; then
        SESSION_TYPE="virtual"
        SESSION_NAME="$USER-virtual-session"
        log "Using virtual sessions for better resolution control"
    else
        SESSION_TYPE="console"
        SESSION_NAME="$USER-session"
        log "Using console sessions"
    fi

    # Create a systemd service for automatic session creation
    log "Creating automatic session startup service..."
    sudo tee /etc/systemd/system/dcv-create-session.service > /dev/null << EOF
[Unit]
Description=Create DCV Session for $USER
After=dcvserver.service
Requires=dcvserver.service
Wants=graphical-session.target

[Service]
Type=oneshot
RemainAfterExit=yes
User=root
ExecStartPre=/bin/sleep 10
ExecStart=/usr/bin/dcv create-session --type=$SESSION_TYPE --owner=$USER $SESSION_NAME
ExecStop=/usr/bin/dcv close-session $SESSION_NAME
TimeoutStartSec=60
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start the session creation service
    sudo systemctl daemon-reload
    sudo systemctl enable dcv-create-session.service

    # Wait a moment for DCV server to be fully ready
    log "Waiting for DCV server to be ready..."
    sleep 5

    # Create initial session
    log "Creating initial $SESSION_TYPE session for user: $USER"
    if sudo dcv create-session --type="$SESSION_TYPE" --owner="$USER" "$SESSION_NAME" 2>/dev/null; then
        log "$SESSION_TYPE session created successfully"
        SESSION_CREATED=true
    else
        warn "Failed to create initial $SESSION_TYPE session. The automatic service will retry on next boot."
        SESSION_CREATED=false
    fi

    # Verify session creation
    log "Verifying DCV session status..."
    if dcv list-sessions | grep -q "$SESSION_NAME"; then
        log "DCV $SESSION_TYPE session is active and ready for connections"
        SESSION_STATUS="Active ($SESSION_TYPE)"
    else
        warn "DCV session may not be active. Check logs: sudo journalctl -u dcv-create-session.service"
        SESSION_STATUS="Not Active"
    fi
else
    log "Automatic session creation disabled"
    SESSION_STATUS="Disabled"
fi

# Display connection information
log "Installation completed successfully!"
echo
echo -e "${BLUE}=== Amazon DCV Server Installation Summary ===${NC}"
echo -e "Ubuntu Version: $UBUNTU_VERSION"
echo -e "Architecture: $ARCH"
echo -e "DCV Server: ${GREEN}Installed and Running${NC}"
echo -e "Desktop Environment: $([ "$INSTALL_DESKTOP" == "true" ] && echo -e "${GREEN}$DESKTOP_ENVIRONMENT Installed${NC}" || echo -e "${YELLOW}Not Installed${NC}")"
echo -e "Web Viewer: $([ "$INSTALL_WEB_VIEWER" == "true" ] && echo -e "${GREEN}Installed${NC}" || echo -e "${YELLOW}Not Installed${NC}")"
echo -e "Virtual Sessions: $([ "$INSTALL_VIRTUAL_SESSIONS" == "true" ] && echo -e "${GREEN}Installed${NC}" || echo -e "${YELLOW}Not Installed${NC}")"
echo -e "XDummy Driver: $([ "$INSTALL_XDUMMY_DRIVER" == "true" ] && [ "$INSTALL_GPU_SUPPORT" != "true" ] && echo -e "${GREEN}Installed${NC}" || echo -e "${YELLOW}Not Installed${NC}")"
echo -e "GPU Support: $([ "$INSTALL_GPU_SUPPORT" == "true" ] && echo -e "${GREEN}Installed${NC}" || echo -e "${YELLOW}Not Installed${NC}")"
echo -e "Auto-start: $([ "$AUTO_START_SERVICE" == "true" ] && echo -e "${GREEN}Enabled${NC}" || echo -e "${YELLOW}Disabled${NC}")"
echo -e "Network Service Fix: $([ "$INSTALL_DESKTOP" == "true" ] && echo -e "${GREEN}Applied${NC}" || echo -e "${YELLOW}Not Applied${NC}")"
echo -e "Wayland Disabled: $([ "$INSTALL_DESKTOP" == "true" ] && echo -e "${GREEN}Yes (X11 Enabled)${NC}" || echo -e "${YELLOW}Not Applied${NC}")"
echo -e "DCV Session: $([ "$SESSION_STATUS" == "Active" ] && echo -e "${GREEN}$SESSION_STATUS${NC}" || echo -e "${YELLOW}$SESSION_STATUS${NC}")"
echo -e "Auto Session Service: ${GREEN}Enabled${NC}"
echo
echo -e "${BLUE}=== Connection Information ===${NC}"
echo -e "DCV Server URL: ${GREEN}https://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || hostname -I | awk '{print $1}'):8443${NC}"
echo -e "Session Name: ${GREEN}$SESSION_NAME${NC}"
echo
echo -e "${BLUE}=== Useful Commands ===${NC}"
echo -e "Check service status: ${GREEN}sudo systemctl status dcvserver${NC}"
echo -e "View service logs: ${GREEN}sudo journalctl -u dcvserver -f${NC}"
echo -e "List sessions: ${GREEN}dcv list-sessions${NC}"
echo -e "Create new session: ${GREEN}dcv create-session --type=console --owner=\$USER my-session${NC}"
echo -e "Delete session: ${GREEN}dcv close-session session-name${NC}"
echo -e "Check failed services: ${GREEN}sudo systemctl --failed${NC}"
echo -e "Check DCV session logs: ${GREEN}sudo tail -f /var/log/dcv/sessionlauncher.log${NC}"
echo -e "Check session service: ${GREEN}sudo systemctl status dcv-create-session.service${NC}"
echo -e "Restart session service: ${GREEN}sudo systemctl restart dcv-create-session.service${NC}"
echo -e "Manual session creation: ${GREEN}sudo dcv create-session --type=console --owner=\$USER \$USER-session${NC}"
echo
echo -e "${YELLOW}Note: Make sure port 8443 is open in your security group for HTTPS access.${NC}"
echo -e "${YELLOW}For QUIC protocol support, also open UDP port 8443.${NC}"

log "Amazon DCV Server installation completed!"
