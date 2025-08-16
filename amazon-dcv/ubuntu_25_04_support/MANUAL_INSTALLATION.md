# Manual Installation Guide for Amazon DCV Client on Ubuntu 25.04

This guide provides step-by-step instructions for manually creating a dummy package to resolve libicu dependency issues when installing Amazon DCV Client on Ubuntu 25.04.

## Prerequisites

- Ubuntu 25.04 system
- Amazon DCV Client DEB package
- Administrative privileges (sudo access)
- Basic familiarity with command line

## Method: Manual Dummy Package Creation

This method creates a compatibility package that satisfies the `libicu74` dependency by depending on the newer `libicu76` package.

### Step 1: Install Required Tools

```bash
sudo apt update
sudo apt install equivs
```

### Step 2: Verify libicu76 Installation

```bash
# Check if libicu76 is installed
dpkg -l | grep libicu76

# If not installed, install it
sudo apt install libicu76
```

### Step 3: Create Working Directory

```bash
mkdir ~/libicu74-dummy
cd ~/libicu74-dummy
```

### Step 4: Create Control File

Create the dummy package control file:

```bash
cat > libicu74-dummy << 'EOF'
Section: misc
Priority: optional
Standards-Version: 3.9.2

Package: libicu74
Version: 74.2-1ubuntu3+compat
Maintainer: Ubuntu 25.04 Compatibility <noreply@localhost>
Architecture: amd64
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
```

**Important notes about the control file:**
- **Architecture**: Change `amd64` to `arm64` if you're on ARM architecture
- **Version**: The version number should be higher than any existing libicu74 package
- **Depends**: Ensures libicu76 is installed when this package is installed
- **Conflicts/Replaces**: Prevents conflicts with real libicu74 packages

### Step 5: Build the Dummy Package

```bash
equivs-build libicu74-dummy
```

This will create a file like `libicu74_74.2-1ubuntu3+compat_amd64.deb`

### Step 6: Install the Dummy Package

```bash
sudo dpkg -i libicu74_*.deb
```

If there are dependency issues:
```bash
sudo apt install -f
```

### Step 7: Verify Dummy Package Installation

```bash
# Check if the dummy package is installed
dpkg -l | grep libicu74

# Verify it provides the libicu74 dependency
apt-cache show libicu74
```

### Step 8: Install Amazon DCV Client

Now you can install the original DCV client package:

```bash
sudo dpkg -i /path/to/dcv-client.deb
```

If there are remaining dependency issues:
```bash
sudo apt install -f
```

### Step 9: Test the Installation

```bash
# Check DCV client version
dcvviewer --version

# Test library dependencies
ldd /usr/bin/dcvviewer | grep libicu

# Run comprehensive test (if available)
./test-dcv-installation.sh
```

## Verification Steps

### 1. Check Package Installation Status

```bash
# List all DCV-related packages
dpkg -l | grep dcv

# Check dummy package status
dpkg -s libicu74
```

### 2. Verify Library Dependencies

```bash
# Check what libraries dcvviewer uses
ldd /usr/bin/dcvviewer

# Specifically check libicu dependencies
ldd /usr/bin/dcvviewer | grep libicu

# Verify library cache
ldconfig -p | grep libicu
```

### 3. Test DCV Client Functionality

```bash
# Basic version check
dcvviewer --version

# Help command (tests basic functionality)
dcvviewer --help

# Check for any missing dependencies
sudo apt install -f
```

## Troubleshooting

### Issue: equivs not found

**Solution:**
```bash
sudo apt update
sudo apt install equivs
```

### Issue: libicu76 not installed

**Solution:**
```bash
sudo apt update
sudo apt install libicu76
```

### Issue: Architecture mismatch

**Symptoms:** Package built for wrong architecture

**Solution:**
```bash
# Check your architecture
dpkg --print-architecture

# Edit the control file and change Architecture line:
# For ARM64: Architecture: arm64
# For AMD64: Architecture: amd64
```

### Issue: Package conflicts

**Symptoms:** Conflicts with existing packages

**Solution:**
```bash
# Remove conflicting packages first
sudo dpkg -r conflicting-package-name

# Or force installation (use with caution)
sudo dpkg -i --force-conflicts libicu74_*.deb
```

### Issue: DCV client still reports missing libicu74

**Diagnosis:**
```bash
# Check if dummy package is properly installed
dpkg -l | grep libicu74

# Check if it provides the right dependency
apt-cache show libicu74
```

**Solution:**
```bash
# Reinstall dummy package
sudo dpkg -r libicu74
sudo dpkg -i libicu74_*.deb

# Update package database
sudo apt update
```

## Rollback Instructions

To completely remove the installation:

```bash
# Remove DCV client (replace with actual package name)
sudo dpkg -r dcv-client-package-name

# Remove dummy package
sudo dpkg -r libicu74

# Clean up any orphaned dependencies
sudo apt autoremove

# Verify removal
dpkg -l | grep -E "(dcv|libicu74)"
```

## Understanding the Solution

### Why This Works

1. **Dependency Satisfaction**: The dummy package provides `libicu74` without actually containing the library
2. **Dependency Mapping**: It depends on `libicu76`, ensuring the newer library is available
3. **ABI Compatibility**: libicu76 is backward compatible with libicu74 applications
4. **Package Management**: Works cleanly with apt/dpkg systems

### Package Relationships

```
Amazon DCV Client
    ↓ (requires)
libicu74 (dummy package)
    ↓ (depends on)
libicu76 (actual library)
```

### What Gets Installed

- **Dummy package**: Satisfies dependency requirements
- **libicu76**: Provides actual library functionality
- **DCV Client**: Uses libicu76 through compatibility layer

## Security Considerations

1. **Package Verification**: Always verify checksums of original DCV packages
2. **Testing**: Test thoroughly in non-production environments
3. **Updates**: Monitor for official Ubuntu 25.04 compatible packages from Amazon
4. **Backup**: Keep original packages for rollback scenarios

## Additional Resources

- [Debian Package Building Guide](https://www.debian.org/doc/manuals/maint-guide/)
- [equivs Documentation](https://manpages.ubuntu.com/manpages/focal/man1/equivs-build.1.html)
- [Amazon DCV User Guide](https://docs.aws.amazon.com/dcv/latest/userguide/)

## Getting Help

If you encounter issues not covered in this guide:

1. Check the main README.md for the automated script solution
2. Review TROUBLESHOOTING.md for additional solutions
3. Check system logs: `journalctl -xe`
4. Consult Amazon DCV documentation for client-specific issues
