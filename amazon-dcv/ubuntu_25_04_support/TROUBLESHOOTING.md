# Troubleshooting Guide - Amazon DCV Client on Ubuntu 25.04

This guide helps resolve common issues when installing and running Amazon DCV Client on Ubuntu 25.04 using the dummy package method for libicu compatibility.

## Common Issues and Solutions

### 1. Dummy Package Creation Issues

#### Issue: "equivs-build command not found"
```bash
bash: equivs-build: command not found
```

**Solution:**
```bash
sudo apt update
sudo apt install equivs
```

#### Issue: "libicu76 not available"
```bash
Package libicu76 is not available, but is referred to by another package
```

**Solution:**
```bash
# Update package lists
sudo apt update

# Install libicu76
sudo apt install libicu76

# If still not available, check Ubuntu version
lsb_release -a
```

#### Issue: Architecture mismatch in dummy package
```bash
dpkg: error processing libicu74_*.deb (--install):
 package architecture (amd64) does not match system (arm64)
```

**Solution:**
Edit the control file before building:
```bash
# Check your system architecture
dpkg --print-architecture

# Edit control file and change Architecture line accordingly
nano libicu74-dummy
# Change: Architecture: amd64
# To:     Architecture: arm64  (or whatever your system shows)

# Rebuild the package
equivs-build libicu74-dummy
```

### 2. Package Installation Issues

#### Issue: "Package has unmet dependencies"
```bash
dpkg: dependency problems prevent configuration of dcv-client:
 dcv-client depends on libicu74; however:
  Package libicu74 is not installed.
```

**Diagnosis:**
```bash
# Check if dummy package is installed
dpkg -l | grep libicu74

# Check if it provides the right dependency
apt-cache show libicu74
```

**Solution:**
```bash
# Install dummy package first
sudo dpkg -i libicu74_*.deb

# Then install DCV client
sudo dpkg -i dcv-client.deb

# Fix any remaining dependencies
sudo apt install -f
```

#### Issue: "Conflicts with existing packages"
```bash
dpkg: regarding libicu74_*.deb containing libicu74:
 libicu74 conflicts with libicu74-dev
```

**Solution:**
```bash
# Remove conflicting packages (if safe to do so)
sudo apt remove libicu74-dev

# Or modify the dummy package to not conflict
# Edit the control file and remove the "Conflicts:" line
```

### 3. Library Loading Issues

#### Issue: "Library not found" errors
```bash
dcvviewer: error while loading shared libraries: libicu74.so: cannot open shared object file
```

**Diagnosis:**
```bash
# Check if libicu76 is actually installed
dpkg -l | grep libicu76

# Check library cache
ldconfig -p | grep libicu

# Check what libraries dcvviewer needs
ldd /usr/bin/dcvviewer | grep libicu
```

**Solution:**
This usually means the dummy package approach isn't working. The application is looking for the actual library file, not just the package dependency.

```bash
# Verify dummy package installation
dpkg -s libicu74

# Check if libicu76 provides the needed symbols
objdump -T /usr/lib/x86_64-linux-gnu/libicuuc.so.76.1 | grep -i icu

# If the issue persists, you may need to create symbolic links as well
cd /usr/lib/x86_64-linux-gnu
sudo ln -sf libicuuc.so.76.1 libicuuc.so.74
sudo ln -sf libicudata.so.76.1 libicudata.so.74
sudo ln -sf libicui18n.so.76.1 libicui18n.so.74
sudo ldconfig
```

#### Issue: "Version mismatch" errors
```bash
dcvviewer: /usr/lib/x86_64-linux-gnu/libicu74.so: version `LIBICU_74' not found
```

**Diagnosis:**
```bash
# Check symbol versions in libicu76
objdump -T /usr/lib/x86_64-linux-gnu/libicuuc.so.76.1 | grep LIBICU
strings /usr/lib/x86_64-linux-gnu/libicuuc.so.76.1 | grep LIBICU
```

**Solution:**
This indicates ABI incompatibility. The dummy package method may not be sufficient:

```bash
# Check if a newer DCV client version is available
# Or consider using an older Ubuntu version for DCV client
```

### 4. DCV Client Runtime Issues

#### Issue: DCV Client crashes on startup
```bash
Segmentation fault (core dumped)
```

**Diagnosis:**
```bash
# Run with debugging
gdb dcvviewer
(gdb) run
(gdb) bt  # when it crashes

# Check system logs
journalctl -xe | grep dcv

# Check DCV logs
ls -la ~/.dcv/
cat ~/.dcv/dcvviewer.log 2>/dev/null || echo "No log file found"
```

**Solutions:**
1. **Check graphics drivers:**
   ```bash
   # For NVIDIA
   nvidia-smi
   
   # For AMD/Intel
   glxinfo | grep renderer
   
   # Update drivers if needed
   sudo ubuntu-drivers autoinstall
   ```

2. **Try software rendering:**
   ```bash
   LIBGL_ALWAYS_SOFTWARE=1 dcvviewer
   ```

3. **Check library compatibility:**
   ```bash
   ldd /usr/bin/dcvviewer | grep "not found"
   ```

#### Issue: Connection failures
```bash
Failed to connect to DCV server
```

**Diagnosis:**
```bash
# Test network connectivity
telnet dcv-server-address 8443

# Check firewall
sudo ufw status

# Verify certificates
openssl s_client -connect dcv-server-address:8443 -verify_return_error
```

**Solutions:**
1. **Network connectivity:**
   ```bash
   # Allow DCV traffic through firewall
   sudo ufw allow 8443/tcp
   sudo ufw allow from dcv-server-ip
   ```

2. **Certificate issues:**
   ```bash
   # Skip certificate verification (testing only)
   dcvviewer --certificate-validation-policy=accept-untrusted
   ```

### 5. System Compatibility Issues

#### Issue: Ubuntu version warnings
```bash
Warning: This package was built for Ubuntu 20.04
```

**Diagnosis:**
```bash
# Check Ubuntu version
lsb_release -a
cat /etc/os-release

# Check kernel version
uname -r
```

**Solution:**
This is usually just a warning and can be ignored if the dummy package method works correctly.

### 6. Package Management Issues

#### Issue: "dpkg database locked"
```bash
dpkg: error: dpkg frontend lock is locked by another process
```

**Solution:**
```bash
# Wait for other package operations to complete, then:
sudo dpkg --configure -a
sudo apt update
```

#### Issue: Broken package dependencies
```bash
You have held broken packages
```

**Solution:**
```bash
# Fix broken dependencies
sudo apt --fix-broken install

# If that doesn't work, remove problematic packages
sudo dpkg -r problematic-package-name
sudo apt autoremove
```

## Diagnostic Commands Reference

### Package Information
```bash
# Check installed packages
dpkg -l | grep -E "(dcv|libicu)"

# Check package status
dpkg -s package-name

# Check package dependencies
apt-cache depends package-name

# Check what provides a dependency
apt-cache search libicu74
```

### Library Information
```bash
# Library cache
ldconfig -p | grep libicu

# Library dependencies
ldd /usr/bin/dcvviewer

# Library locations
find /usr/lib -name "*libicu*" 2>/dev/null

# Symbol information
nm -D /usr/lib/x86_64-linux-gnu/libicuuc.so.76.1 | grep -i icu
objdump -T /usr/lib/x86_64-linux-gnu/libicuuc.so.76.1 | grep LIBICU
```

### System Information
```bash
# OS and architecture
lsb_release -a
dpkg --print-architecture
uname -a

# Available memory and CPU
free -h
nproc
```

## Recovery Procedures

### Complete Removal and Reinstall

```bash
# Remove DCV client
sudo dpkg -r dcv-client-package-name

# Remove dummy package
sudo dpkg -r libicu74

# Clean package cache
sudo apt clean
sudo apt autoremove

# Fix any broken dependencies
sudo apt --fix-broken install

# Start fresh with dummy package method
./create-libicu74-dummy.sh
sudo dpkg -i libicu74_*.deb
sudo dpkg -i dcv-client.deb
```

### Reset DCV Client Configuration

```bash
# Backup current config
cp -r ~/.dcv ~/.dcv.backup 2>/dev/null || echo "No config to backup"

# Remove configuration
rm -rf ~/.dcv

# Restart DCV client (will recreate default config)
dcvviewer
```

## Advanced Troubleshooting

### Debug Library Loading

```bash
# Enable library debugging
export LD_DEBUG=libs
dcvviewer --version
unset LD_DEBUG

# Check library search paths
echo $LD_LIBRARY_PATH
ldconfig -v | grep libicu
```

### Verify Dummy Package Functionality

```bash
# Check if dummy package satisfies dependency
apt-cache policy libicu74

# Verify dependency resolution
apt-cache depends dcv-client-package-name

# Test dependency satisfaction
dpkg-checkbuilddeps (if you have build tools)
```

### Create Support Bundle

```bash
# Create comprehensive diagnostic information
mkdir dcv-debug-$(date +%Y%m%d)
cd dcv-debug-$(date +%Y%m%d)

# System information
lsb_release -a > system-info.txt
uname -a >> system-info.txt
dpkg --print-architecture >> system-info.txt

# Package information
dpkg -l | grep -E "(dcv|libicu)" > packages.txt
apt-cache policy libicu74 > libicu74-policy.txt
apt-cache show libicu74 > libicu74-show.txt

# Library information
ldconfig -p | grep libicu > library-cache.txt
ldd /usr/bin/dcvviewer > dcv-dependencies.txt 2>&1
find /usr/lib -name "*libicu*" > libicu-files.txt 2>/dev/null

# Logs
cp ~/.dcv/dcvviewer.log . 2>/dev/null || echo "No dcvviewer.log found"
journalctl -xe > system-logs.txt

# Create archive
cd ..
tar -czf dcv-debug-$(date +%Y%m%d).tar.gz dcv-debug-$(date +%Y%m%d)/
echo "Debug bundle created: dcv-debug-$(date +%Y%m%d).tar.gz"
```

## Getting Additional Help

### Community Resources
- [Amazon DCV Forums](https://forums.aws.amazon.com/forum.jspa?forumID=316)
- [Ubuntu Community Support](https://askubuntu.com/)
- [Stack Overflow - DCV Tag](https://stackoverflow.com/questions/tagged/amazon-dcv)

### Official Documentation
- [Amazon DCV User Guide](https://docs.aws.amazon.com/dcv/latest/userguide/)
- [Amazon DCV Administrator Guide](https://docs.aws.amazon.com/dcv/latest/adminguide/)
- [Ubuntu Package Management](https://help.ubuntu.com/community/AptGet/Howto)

### When to Seek Help

Contact support or community forums when:
1. The dummy package method fails completely
2. You encounter library symbol version conflicts
3. DCV client crashes consistently after successful installation
4. You need to support multiple different library versions
5. Security concerns about the compatibility approach
