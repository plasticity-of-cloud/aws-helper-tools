#!/bin/bash

set -e

# Set non-interactive mode
export DEBIAN_FRONTEND=noninteractive

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
    sudo apt-get install -y ubuntu-desktop-minimal

    # Install DCV packages directly (skip GPG verification for now)
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] Installing DCV server package..."
    sudo dpkg -i nice-dcv-server*.deb || true
    sudo apt-get install -f -y

    # Install additional packages if they exist
    for pkg in nice-dcv-web-viewer*.deb nice-xdcv*.deb; do
        if [ -f "$pkg" ]; then
            echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] Installing $pkg..."
            sudo dpkg -i "$pkg" || true
            sudo apt-get install -f -y
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

# Wait for DCV to start
sleep 5

# Create virtual session for ubuntu user
echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] Creating DCV virtual session..."
sudo dcv create-session --type=virtual --owner ubuntu --storage-root /home/ubuntu ubuntu-session || true

# Clean up
cd
rm -rf $TEMP_DIR

echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] DCV Server installation complete${NC}"
echo -e "${GREEN}DCV Server status:${NC}"
sudo systemctl status dcvserver --no-pager
echo -e "${GREEN}DCV Sessions:${NC}"
dcv list-sessions
