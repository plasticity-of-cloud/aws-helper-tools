# Amazon DCV Server Installation Tools

Automated installation scripts for Amazon DCV Server on Ubuntu systems running in AWS infrastructure.

## Overview

Amazon DCV (Desktop Cloud Visualization) is a high-performance remote display protocol that provides customers with a secure way to deliver remote desktops and application streaming from any cloud or data center to any device, over varying network conditions.

## Features

- **Complete Desktop Environment**: Installs Ubuntu desktop with full graphical interface
- **Multiple Desktop Options**: Choose from GNOME, XFCE4, KDE, or minimal installations
- **Screensaver Management**: Automatically disables screensaver and lock screen for uninterrupted sessions
- **Session Types**: Supports both console and virtual sessions
- **GPU Support**: Hardware acceleration for graphics workloads
- **AWS Optimized**: Configured for EC2 instances with proper security groups
- **Network Service Fix**: Automatically resolves systemd-networkd-wait-online timeout issues on EC2
- **X11 Compatibility**: Automatically disables Wayland for DCV compatibility
- **Auto Session Creation**: Automatically creates and starts DCV sessions on boot
- **Hibernation Compatible**: Works with EC2 Spot Instance hibernation workflows

## Quick Start

```bash
# Basic installation with Ubuntu desktop
./install-dcv-ubuntu.sh

# Custom installation
source dcv-install-config.sh
# Edit configuration as needed
./install-dcv-ubuntu.sh
```

## Files

- `install-dcv-ubuntu.sh` - Main installation script
- `dcv-install-config.sh` - Configuration options
- `DCV-INSTALLATION.md` - Comprehensive documentation

## Requirements

- Ubuntu 20.04/22.04/24.04 (x86_64 or ARM64)
- At least 2.4GB RAM (t3.medium or larger recommended)
- AWS EC2 instance with internet connectivity
- Security group allowing port 8443 (TCP/UDP)

## Documentation

See [DCV-INSTALLATION.md](DCV-INSTALLATION.md) for complete installation guide, configuration options, and troubleshooting information.

## Support

Based on official AWS documentation:
- [Amazon DCV Administrator Guide](https://docs.aws.amazon.com/dcv/latest/adminguide/)
- [Amazon DCV User Guide](https://docs.aws.amazon.com/dcv/latest/userguide/)
