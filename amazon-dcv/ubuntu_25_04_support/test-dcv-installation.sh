#!/bin/bash

# Test script for Amazon DCV Client installation on Ubuntu 25.04
# This script verifies the installation and functionality of DCV client

set -e

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

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    log_info "Running test: $test_name"
    
    if eval "$test_command" >/dev/null 2>&1; then
        log_success "✓ $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_error "✗ $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

run_test_with_output() {
    local test_name="$1"
    local test_command="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    log_info "Running test: $test_name"
    
    local output
    output=$(eval "$test_command" 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        log_success "✓ $test_name"
        echo "  Output: $output"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_error "✗ $test_name"
        echo "  Error: $output"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# System compatibility tests
test_system_compatibility() {
    echo
    log_info "=== System Compatibility Tests ==="
    
    run_test_with_output "Ubuntu version check" "lsb_release -r | grep -E '(25\.04|24\.10|24\.04)'"
    run_test "Architecture check" "dpkg --print-architecture | grep -E '(amd64|arm64)'"
    run_test "libicu76 availability" "dpkg -l | grep -q libicu76"
}

# Package installation tests
test_package_installation() {
    echo
    log_info "=== Package Installation Tests ==="
    
    run_test "DCV client package installed" "dpkg -l | grep -q dcv"
    
    if dpkg -l | grep -q dcv; then
        local dcv_package=$(dpkg -l | grep dcv | awk '{print $2}' | head -1)
        run_test_with_output "DCV package version" "dpkg -l | grep dcv | head -1 | awk '{print \$3}'"
        run_test "DCV package status" "dpkg -s $dcv_package | grep -q 'Status: install ok installed'"
    fi
}

# Library dependency tests
test_library_dependencies() {
    echo
    log_info "=== Library Dependency Tests ==="
    
    # Check if dcvviewer exists
    if command -v dcvviewer >/dev/null 2>&1; then
        run_test "dcvviewer executable exists" "test -x /usr/bin/dcvviewer"
        run_test "dcvviewer library dependencies" "ldd /usr/bin/dcvviewer >/dev/null"
        
        # Check specific libicu dependencies
        if ldd /usr/bin/dcvviewer | grep -q libicu; then
            log_info "Checking libicu dependencies:"
            ldd /usr/bin/dcvviewer | grep libicu | sed 's/^/  /'
            
            # Check if all libicu libraries are found
            local missing_libs=0
            while read -r lib; do
                if echo "$lib" | grep -q "not found"; then
                    log_error "Missing library: $lib"
                    missing_libs=$((missing_libs + 1))
                fi
            done < <(ldd /usr/bin/dcvviewer | grep libicu)
            
            if [ $missing_libs -eq 0 ]; then
                log_success "All libicu dependencies resolved"
                TESTS_PASSED=$((TESTS_PASSED + 1))
            else
                log_error "$missing_libs libicu dependencies missing"
                TESTS_FAILED=$((TESTS_FAILED + 1))
            fi
            TESTS_TOTAL=$((TESTS_TOTAL + 1))
        fi
    else
        log_error "dcvviewer executable not found"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TESTS_TOTAL=$((TESTS_TOTAL + 1))
    fi
    
    # Check library cache
    run_test "libicu in library cache" "ldconfig -p | grep -q libicu"
}

# Functional tests
test_dcv_functionality() {
    echo
    log_info "=== DCV Client Functionality Tests ==="
    
    if command -v dcvviewer >/dev/null 2>&1; then
        run_test_with_output "dcvviewer version" "dcvviewer --version"
        run_test "dcvviewer help" "dcvviewer --help >/dev/null"
        
        # Test basic startup (without connecting)
        log_info "Testing dcvviewer startup (5 second timeout)..."
        if timeout 5s dcvviewer --help >/dev/null 2>&1; then
            log_success "✓ dcvviewer starts without errors"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            log_error "✗ dcvviewer startup issues"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
        TESTS_TOTAL=$((TESTS_TOTAL + 1))
    fi
}

# Graphics and audio tests
test_graphics_audio() {
    echo
    log_info "=== Graphics and Audio Tests ==="
    
    # Graphics tests
    run_test "OpenGL support" "command -v glxinfo >/dev/null && glxinfo | grep -q 'direct rendering'"
    run_test "X11 display available" "test -n \"\$DISPLAY\""
    
    # Audio tests
    run_test "PulseAudio available" "command -v pulseaudio >/dev/null"
    if command -v pulseaudio >/dev/null 2>&1; then
        run_test "PulseAudio running" "pulseaudio --check"
    fi
}

# Network tests
test_network_capabilities() {
    echo
    log_info "=== Network Capability Tests ==="
    
    run_test "SSL/TLS support" "command -v openssl >/dev/null"
    run_test "Network tools available" "command -v telnet >/dev/null || command -v nc >/dev/null"
    
    # Test if we can resolve common DCV ports (not connecting, just checking tools)
    if command -v ss >/dev/null 2>&1; then
        run_test "Network socket tools" "ss --version >/dev/null"
    fi
}

# Configuration tests
test_configuration() {
    echo
    log_info "=== Configuration Tests ==="
    
    # Check DCV configuration directory
    local dcv_config_dir="$HOME/.dcv"
    
    if [ -d "$dcv_config_dir" ]; then
        run_test "DCV config directory exists" "test -d $dcv_config_dir"
        run_test "DCV config directory writable" "test -w $dcv_config_dir"
    else
        log_info "DCV config directory doesn't exist yet (normal for first run)"
    fi
    
    # Check system-wide configuration
    if [ -d "/etc/dcv" ]; then
        run_test "System DCV config exists" "test -d /etc/dcv"
    fi
}

# Compatibility layer tests
test_compatibility_layer() {
    echo
    log_info "=== Compatibility Layer Tests ==="
    
    # Check if libicu74 compatibility is in place
    if ls /usr/lib/*/libicu*.so.74* >/dev/null 2>&1; then
        log_info "libicu74 compatibility layer detected:"
        ls /usr/lib/*/libicu*.so.74* | sed 's/^/  /'
        
        # Check if they're symbolic links (expected)
        local symlink_count=0
        local regular_count=0
        
        for lib in /usr/lib/*/libicu*.so.74*; do
            if [ -L "$lib" ]; then
                symlink_count=$((symlink_count + 1))
            elif [ -f "$lib" ]; then
                regular_count=$((regular_count + 1))
            fi
        done
        
        if [ $symlink_count -gt 0 ]; then
            log_success "✓ Found $symlink_count libicu74 symbolic links"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        fi
        
        if [ $regular_count -gt 0 ]; then
            log_info "Found $regular_count regular libicu74 files (dummy package or real libs)"
        fi
        
        TESTS_TOTAL=$((TESTS_TOTAL + 1))
    fi
    
    # Check for dummy packages
    if dpkg -l | grep -q "libicu74.*compat"; then
        log_success "✓ libicu74 dummy package detected"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TESTS_TOTAL=$((TESTS_TOTAL + 1))
    fi
}

# Performance tests
test_performance() {
    echo
    log_info "=== Performance Tests ==="
    
    # Check available memory
    local mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local mem_gb=$((mem_total / 1024 / 1024))
    
    if [ $mem_gb -ge 2 ]; then
        log_success "✓ Sufficient memory: ${mem_gb}GB"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_warning "Low memory: ${mem_gb}GB (recommended: 2GB+)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    # Check CPU
    local cpu_count=$(nproc)
    if [ $cpu_count -ge 2 ]; then
        log_success "✓ Sufficient CPU cores: $cpu_count"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_warning "Limited CPU cores: $cpu_count (recommended: 2+)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

# Generate report
generate_report() {
    echo
    log_info "=== Test Report ==="
    echo
    echo "Total tests run: $TESTS_TOTAL"
    echo "Tests passed: $TESTS_PASSED"
    echo "Tests failed: $TESTS_FAILED"
    echo
    
    local success_rate=0
    if [ $TESTS_TOTAL -gt 0 ]; then
        success_rate=$((TESTS_PASSED * 100 / TESTS_TOTAL))
    fi
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log_success "All tests passed! DCV Client should work correctly."
    elif [ $success_rate -ge 80 ]; then
        log_warning "Most tests passed ($success_rate%). DCV Client should work with minor issues."
    else
        log_error "Many tests failed ($success_rate%). DCV Client may have significant issues."
    fi
    
    echo
    echo "Recommendations:"
    
    if [ $TESTS_FAILED -gt 0 ]; then
        echo "- Review failed tests above"
        echo "- Check TROUBLESHOOTING.md for solutions"
        echo "- Ensure all dependencies are properly installed"
    fi
    
    if ! command -v dcvviewer >/dev/null 2>&1; then
        echo "- Install DCV Client package first"
    fi
    
    if ! dpkg -l | grep -q libicu76; then
        echo "- Install libicu76: sudo apt install libicu76"
    fi
    
    echo "- Test actual DCV connection to verify full functionality"
    echo "- Check graphics drivers if planning to use GPU acceleration"
}

# Main execution
main() {
    log_info "Amazon DCV Client Installation Test for Ubuntu 25.04"
    log_info "This script tests the installation and basic functionality of DCV Client"
    echo
    
    test_system_compatibility
    test_package_installation
    test_library_dependencies
    test_dcv_functionality
    test_graphics_audio
    test_network_capabilities
    test_configuration
    test_compatibility_layer
    test_performance
    generate_report
}

# Handle command line arguments
case "${1:-}" in
    --help)
        echo "Usage: $0 [--help]"
        echo
        echo "This script tests Amazon DCV Client installation on Ubuntu 25.04"
        echo "It checks system compatibility, package installation, library dependencies,"
        echo "and basic functionality."
        echo
        echo "No arguments are required - just run the script to perform all tests."
        exit 0
        ;;
    "")
        # Default action - run all tests
        ;;
    *)
        log_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac

main
