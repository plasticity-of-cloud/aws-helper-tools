#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get architecture
ARCH=$(dpkg --print-architecture)
echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] Architecture detected: $ARCH"

# Set package URL based on architecture
if [ "$ARCH" = "arm64" ]; then
    DCV_URL="https://d1uj6qtbmh3dt5.cloudfront.net/2024.0/Servers/nice-dcv-2024.0-19030-ubuntu2204-aarch64.tgz"
else
    DCV_URL="https://d1uj6qtbmh3dt5.cloudfront.net/2024.0/Servers/nice-dcv-2024.0-19030-ubuntu2204-x86_64.tgz"
fi

# Create temp directory
TEMP_DIR=$(mktemp -d)
cd $TEMP_DIR

echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] Downloading and importing Amazon DCV GPG key..."
curl -fsSL https://d1uj6qtbmh3dt5.cloudfront.net/NICE-GPG-KEY | sudo gpg --dearmor -o /usr/share/keyrings/nice-dcv-archive-keyring.gpg

echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] Downloading Amazon DCV packages..."
wget $DCV_URL -O dcv-server.tgz

echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] Extracting DCV packages..."
tar xf dcv-server.tgz

# Find and install all .deb packages
echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] Installing Amazon DCV Server..."
if [ -d nice-dcv-* ]; then
    cd nice-dcv-*
    # Install dependencies first
    sudo apt-get update
    sudo apt-get install -y \
        ubuntu-desktop \
        xfce4 \
        xfce4-terminal \
        dbus-x11 \
        x11-xserver-utils \
        python3-websocket \
        libgles2

    # Install DCV packages in correct order
    for pkg in nice-dcv-gl*.deb nice-dcv-server*.deb nice-dcv-web-viewer*.deb; do
        if [ -f "$pkg" ]; then
            echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] Installing $pkg..."
            sudo dpkg -i "$pkg"
        fi
    done
else
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: DCV Server package directory not found${NC}"
    exit 1
fi

# Configure DCV
echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] Configuring DCV Server..."
sudo systemctl enable dcvserver
sudo systemctl start dcvserver

# Clean up
cd
rm -rf $TEMP_DIR

echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] DCV Server installation complete${NC}"
echo -e "${GREEN}DCV Server status:${NC}"
sudo systemctl status dcvserver
