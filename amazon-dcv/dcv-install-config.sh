#!/bin/bash

# Amazon DCV Server Installation Configuration
# Source this file before running install-dcv-ubuntu.sh to customize the installation
# Usage: source dcv-install-config.sh && ./install-dcv-ubuntu.sh

# Core DCV Server is always installed

# Install Desktop Environment
# Recommended: true (required for virtual sessions)
export INSTALL_DESKTOP=true

# Desktop Environment to install
# Options: ubuntu-desktop-minimal, ubuntu-desktop, gnome-session, xfce4, kde-plasma-desktop
# Recommended: ubuntu-desktop-minimal (lighter, faster)
export DESKTOP_ENVIRONMENT="ubuntu-desktop-minimal"

# Install DCV Web Viewer (allows browser-based connections)
# Recommended: true
export INSTALL_WEB_VIEWER=true

# Install Virtual Sessions support (nice-xdcv)
# Allows creating virtual desktop sessions
# Recommended: true (requires desktop environment)
export INSTALL_VIRTUAL_SESSIONS=true

# Install GPU support (nice-dcv-gl)
# Only available on x86_64 architecture
# Set to true if you have GPU instances (G4, G5, P3, P4, etc.)
export INSTALL_GPU_SUPPORT=false

# Install XDummy driver for non-GPU instances
# Enables flexible display resolution control for virtual sessions
# Recommended: true (unless using GPU instances)
export INSTALL_XDUMMY_DRIVER=true

# Install External Authenticator
# Required for integration with Amazon DCV EnginFrame
# Most users don't need this
export INSTALL_EXTERNAL_AUTH=false

# Install USB remotization support
# Allows forwarding specialized USB devices
# Most users don't need this
export INSTALL_USB_REMOTIZATION=false

# Install PulseAudio utilities
# Required for microphone redirection
# Recommended: true
export INSTALL_PULSEAUDIO=true

# Auto-start DCV service on boot
# Recommended: true
export AUTO_START_SERVICE=true

# Auto-create DCV session for current user
# Recommended: true (creates session automatically on boot)
export AUTO_CREATE_SESSION=true

# Use virtual sessions instead of console sessions
# Recommended: true (provides better resolution control with XDummy driver)
export USE_VIRTUAL_SESSIONS=true

# Disable screensaver
# Recommended: true (prevents session interruption)
export DISABLE_SCREENSAVER=true

# Disable lock screen
# Recommended: true (prevents session lockout)
export DISABLE_LOCK_SCREEN=true

echo "DCV installation configuration loaded:"
echo "  Desktop Environment: $INSTALL_DESKTOP ($DESKTOP_ENVIRONMENT)"
echo "  Web Viewer: $INSTALL_WEB_VIEWER"
echo "  Virtual Sessions: $INSTALL_VIRTUAL_SESSIONS"
echo "  XDummy Driver: $INSTALL_XDUMMY_DRIVER"
echo "  GPU Support: $INSTALL_GPU_SUPPORT"
echo "  External Auth: $INSTALL_EXTERNAL_AUTH"
echo "  USB Remotization: $INSTALL_USB_REMOTIZATION"
echo "  PulseAudio: $INSTALL_PULSEAUDIO"
echo "  Auto-start: $AUTO_START_SERVICE"
echo "  Auto-create Session: $AUTO_CREATE_SESSION"
echo "  Use Virtual Sessions: $USE_VIRTUAL_SESSIONS"
echo "  Disable Screensaver: $DISABLE_SCREENSAVER"
echo "  Disable Lock Screen: $DISABLE_LOCK_SCREEN"
echo
echo "Available desktop environments:"
echo "  ubuntu-desktop-minimal  - Ubuntu Desktop (minimal, recommended)"
echo "  ubuntu-desktop         - Ubuntu Desktop (full)"
echo "  gnome-session          - GNOME session only"
echo "  xfce4                  - XFCE4 (lightweight)"
echo "  kde-plasma-desktop     - KDE Plasma"
echo
echo "Run: ./install-dcv-ubuntu.sh"
