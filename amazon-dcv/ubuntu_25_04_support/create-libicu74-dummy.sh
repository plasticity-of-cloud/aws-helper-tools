#!/bin/bash

# Create libicu74 dummy package for Ubuntu 25.04
# This creates a compatibility package that satisfies libicu74 dependency
# by depending on the newer libicu76 package

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="libicu74_dummy_$(date +%s)"
WORK_DIR_FULL="$SCRIPT_DIR/$WORK_DIR"

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if equivs is installed
check_dependencies() {
    if ! command -v equivs-build &> /dev/null; then
        log_error "equivs is not installed. Installing it now..."
        sudo apt update
        sudo apt install -y equivs
    fi
    
    # Check if libicu76 is available
    if ! dpkg -l | grep -q "libicu76"; then
        log_warning "libicu76 not found. You may need to install it:"
        echo "  sudo apt update && sudo apt install libicu76"
    fi
}

# Create dummy package control file
create_control_file() {
    log_info "Creating dummy package control file..."
    
    mkdir -p "$WORK_DIR_FULL"
    cd "$WORK_DIR_FULL"
    
    # Get system architecture
    ARCH=$(dpkg --print-architecture)
    
    # Get libicu76 version if available
    LIBICU76_VERSION=$(dpkg -l | grep "libicu76" | awk '{print $3}' | head -1)
    if [ -z "$LIBICU76_VERSION" ]; then
        LIBICU76_VERSION="76.1-1ubuntu1"
        log_warning "libicu76 not found, using default version: $LIBICU76_VERSION"
    fi
    
    # Create the control file
    cat > libicu74-dummy << EOF
Section: misc
Priority: optional
Standards-Version: 3.9.2

Package: libicu74
Version: 74.2-1ubuntu3+compat
Maintainer: Ubuntu 25.04 Compatibility <noreply@localhost>
Architecture: $ARCH
Provides: libicu74
Depends: libicu76 (>= 76.1)
Conflicts: libicu74
Replaces: libicu74
Description: Dummy package to satisfy libicu74 dependency on Ubuntu 25.04
 This is a compatibility package that provides libicu74 functionality
 by depending on the newer libicu76 package available in Ubuntu 25.04.
 .
 This package allows installation of applications that depend on libicu74
 while using the newer libicu76 library which maintains backward compatibility.
 .
 Created for Amazon DCV Client compatibility on Ubuntu 25.04.
EOF

    log_info "Control file created for architecture: $ARCH"
}

# Build the dummy package
build_dummy_package() {
    log_info "Building dummy package..."
    
    if ! equivs-build libicu74-dummy; then
        log_error "Failed to build dummy package"
        exit 1
    fi
    
    # Move the package to the script directory
    DUMMY_DEB=$(ls libicu74_*.deb 2>/dev/null | head -1)
    if [ -n "$DUMMY_DEB" ]; then
        mv "$DUMMY_DEB" "$SCRIPT_DIR/"
        DUMMY_DEB_NAME=$(basename "$DUMMY_DEB")
        log_success "Dummy package created: $DUMMY_DEB_NAME"
    else
        log_error "Dummy package not found after build"
        exit 1
    fi
}

# Cleanup
cleanup() {
    cd "$SCRIPT_DIR"
    if [ -d "$WORK_DIR_FULL" ]; then
        rm -rf "$WORK_DIR_FULL"
    fi
}

# Show installation instructions
show_instructions() {
    echo
    log_success "Dummy package creation completed!"
    echo
    echo "Installation instructions:"
    echo "  1. Install the dummy package first:"
    echo "     sudo dpkg -i $DUMMY_DEB_NAME"
    echo
    echo "  2. If there are dependency issues, run:"
    echo "     sudo apt install -f"
    echo
    echo "  3. Now install your Amazon DCV Client package:"
    echo "     sudo dpkg -i your-dcv-client.deb"
    echo
    echo "  4. Verify installation:"
    echo "     dcvviewer --version"
    echo
    echo "Rollback instructions:"
    echo "  sudo dpkg -r dcv-client-package-name"
    echo "  sudo dpkg -r libicu74"
    echo
    echo "Package information:"
    dpkg-deb -I "$SCRIPT_DIR/$DUMMY_DEB_NAME" | grep -E "^(Package|Version|Architecture|Depends|Provides):" | sed 's/^/  /'
}

# Trap for cleanup
trap cleanup EXIT

# Main execution
main() {
    log_info "Creating libicu74 dummy package for Ubuntu 25.04"
    echo
    
    check_dependencies
    create_control_file
    build_dummy_package
    show_instructions
}

main "$@"
