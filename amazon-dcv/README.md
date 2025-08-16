# Amazon DCV Server Installation

Automated installation scripts for Amazon DCV Server on Ubuntu systems.

## Features

- Complete desktop environment installation (GNOME, XFCE4, KDE)
- Automatic screensaver and lock screen disabling
- Support for console and virtual sessions
- GPU acceleration support
- AWS EC2 optimized configuration
- Compatible with EC2 Spot Instance hibernation

## Quick Start

### DCV Server Installation

```bash
cd amazon-dcv
./install-dcv-ubuntu.sh
```

### DCV Client on Ubuntu 25.04

For Ubuntu 25.04 systems that need to install the DCV Client, see the specialized support directory:

```bash
cd ubuntu_25_04_support
./create-libicu74-dummy.sh
sudo dpkg -i libicu74_*.deb
sudo dpkg -i your-dcv-client.deb
```

## Directory Structure

- **Root directory**: DCV Server installation scripts
- **`ubuntu_25_04_support/`**: Tools and documentation for DCV Client installation on Ubuntu 25.04

## Ubuntu 25.04 DCV Client Support

Ubuntu 25.04 ships with newer library versions (like `libicu76`) that may cause compatibility issues with DCV Client packages built for older Ubuntu versions. The `ubuntu_25_04_support` directory provides a **dummy package solution** that:

- ✅ **Maintains clean package management** - Works with apt/dpkg
- ✅ **Preserves system integrity** - No direct file modifications
- ✅ **Handles dependency resolution** - Automatic mapping to newer libraries
- ✅ **Supports proper installation/removal** - Standard package operations
- ✅ **Provides backward compatibility** - libicu76 is compatible with libicu74 applications

### Quick DCV Client Installation on Ubuntu 25.04

1. **Download the DCV Client DEB package** from AWS
2. **Create and install the compatibility package**:
   ```bash
   cd ubuntu_25_04_support
   ./create-libicu74-dummy.sh
   sudo dpkg -i libicu74_*.deb
   ```
3. **Install the DCV client**:
   ```bash
   sudo dpkg -i your-dcv-client.deb
   sudo apt install -f  # Fix any remaining dependencies
   ```
4. **Test the installation**:
   ```bash
   ./test-dcv-installation.sh
   dcvviewer --version
   ```

For detailed instructions, troubleshooting, and manual procedures, see the [Ubuntu 25.04 Support README](ubuntu_25_04_support/README.md).

## System Requirements

### DCV Server
- Ubuntu 18.04, 20.04, 22.04, or 24.04
- Minimum 2GB RAM
- GPU (optional, for hardware acceleration)
- EC2 instance with appropriate security groups

### DCV Client (Ubuntu 25.04)
- Ubuntu 25.04 (or 24.10, 24.04 with newer libraries)
- libicu76 installed
- X11 or Wayland display server
- Audio system (PulseAudio recommended)

## Installation Options

### Server Installation Types

1. **Full Desktop Environment**
   - GNOME (default)
   - XFCE4 (lightweight)
   - KDE Plasma (feature-rich)

2. **Session Types**
   - Console sessions (direct hardware access)
   - Virtual sessions (software rendering)

3. **GPU Support**
   - NVIDIA GPU acceleration
   - AMD GPU support
   - Software rendering fallback

### Client Installation Method (Ubuntu 25.04)

**Dummy Package Approach:**
- Creates a compatibility package that satisfies `libicu74` dependency
- Maps the dependency to the installed `libicu76` library
- Maintains proper package management and dependency resolution
- Allows clean installation and removal of DCV client

**How it works:**
```
DCV Client → requires libicu74 → dummy package → depends on libicu76 (installed)
```

## Configuration

### Server Configuration

The installation script automatically configures:
- DCV server settings (`/etc/dcv/dcv.conf`)
- Desktop environment optimization
- GPU acceleration (if available)
- Firewall rules for DCV ports
- Automatic service startup

### Client Configuration

After installation, DCV Client configuration is stored in:
- User settings: `~/.dcv/`
- System settings: `/etc/dcv/` (if applicable)

## Security Considerations

### Server Security
- Configure appropriate security groups
- Use strong authentication
- Enable TLS encryption
- Regular security updates

### Client Security
- Verify package integrity before installation
- Test in non-production environments first
- Keep original packages for rollback
- Monitor for security updates from Amazon
- The dummy package only affects dependency resolution, not library loading

## Troubleshooting

### Server Issues
- Check service status: `sudo systemctl status dcvserver`
- Review logs: `sudo journalctl -u dcvserver`
- Verify GPU drivers: `nvidia-smi` or `lspci | grep VGA`

### Client Issues (Ubuntu 25.04)
- Use the test script: `./ubuntu_25_04_support/test-dcv-installation.sh`
- Check library dependencies: `ldd /usr/bin/dcvviewer`
- Review troubleshooting guide: [TROUBLESHOOTING.md](ubuntu_25_04_support/TROUBLESHOOTING.md)

## Advanced Usage

### Custom Server Configuration
```bash
# Edit DCV configuration
sudo nano /etc/dcv/dcv.conf

# Restart DCV service
sudo systemctl restart dcvserver
```

### Batch Client Processing
```bash
# Create dummy package once, use on multiple systems
cd ubuntu_25_04_support
./create-libicu74-dummy.sh

# Deploy to multiple systems
scp libicu74_*.deb user@target-system:
ssh user@target-system "sudo dpkg -i libicu74_*.deb && sudo dpkg -i dcv-client.deb"
```

## Support and Documentation

### Official Resources
- [Amazon DCV User Guide](https://docs.aws.amazon.com/dcv/latest/userguide/)
- [Amazon DCV Administrator Guide](https://docs.aws.amazon.com/dcv/latest/adminguide/)
- [DCV Client Downloads](https://download.nice-dcv.com/)

### Community Support
- [AWS Forums - DCV](https://forums.aws.amazon.com/forum.jspa?forumID=316)
- [Ubuntu Community](https://askubuntu.com/)

### Project Resources
- [Main Project README](../README.md)
- [Ubuntu 25.04 Support Documentation](ubuntu_25_04_support/)
- [Manual Installation Guide](ubuntu_25_04_support/MANUAL_INSTALLATION.md)
- [Troubleshooting Guide](ubuntu_25_04_support/TROUBLESHOOTING.md)

## Contributing

Contributions are welcome! Areas where help is needed:

1. **Testing on different Ubuntu versions**
2. **Support for other Linux distributions**
3. **Additional compatibility fixes**
4. **Documentation improvements**
5. **Automated testing enhancements**

Please test thoroughly and document any new compatibility issues or solutions.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](../LICENSE) file for details.
