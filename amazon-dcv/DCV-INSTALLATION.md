# Amazon DCV Server Installation for Ubuntu

This directory contains scripts to install Amazon DCV Server on Ubuntu x86_64 systems running in AWS infrastructure, including desktop environment installation and configuration.

## Files

- `install-dcv-ubuntu.sh` - Main installation script with desktop environment support
- `dcv-install-config.sh` - Configuration file for customizing installation options
- `DCV-INSTALLATION.md` - This documentation file

## Quick Start

### Complete Installation (Recommended)

```bash
./install-dcv-ubuntu.sh
```

This will install:
- Ubuntu Desktop (minimal) environment
- Core DCV Server
- Web Viewer (browser access)
- Virtual Sessions support
- PulseAudio utilities (microphone support)
- Auto-start on boot
- Disabled screensaver and lock screen

### Custom Installation

1. Configure installation options:
```bash
source dcv-install-config.sh
```

2. Edit the configuration variables as needed, then run:
```bash
./install-dcv-ubuntu.sh
```

### GPU-Enabled Installation

For GPU instances (G4, G5, P3, P4, etc.):

```bash
export INSTALL_GPU_SUPPORT=true
./install-dcv-ubuntu.sh
```

### Minimal Installation (DCV only, no desktop)

```bash
export INSTALL_DESKTOP=false
export INSTALL_VIRTUAL_SESSIONS=false
./install-dcv-ubuntu.sh
```

## Supported Platforms

- **Ubuntu 20.04 LTS** (x86_64, ARM64)
- **Ubuntu 22.04 LTS** (x86_64, ARM64)
- **Ubuntu 24.04 LTS** (x86_64, ARM64)

## Prerequisites

- Ubuntu system running on AWS EC2
- User with sudo privileges
- Internet connectivity for downloading packages
- Security group allowing inbound traffic on port 8443 (TCP/UDP)
- **At least 2.4GB RAM** for desktop environment (t3.medium or larger recommended)

## Desktop Environment Options

The script supports multiple desktop environments:

- **ubuntu-desktop-minimal** (default) - Lightweight Ubuntu desktop
- **ubuntu-desktop** - Full Ubuntu desktop with all applications
- **gnome-session** - GNOME session only
- **xfce4** - Lightweight XFCE4 desktop
- **kde-plasma-desktop** - KDE Plasma desktop

## Installation Components

### Core Components (Always Installed)
- **DCV Server**: Main server component
- **dcv user**: Added to video group for proper permissions

### Desktop Environment Components (Optional)
- **Desktop Environment**: Full graphical desktop (GNOME, XFCE4, KDE, etc.)
- **Essential Applications**: Firefox, text editor, file manager, terminal
- **X11 Utilities**: Display and window management tools
- **Screensaver/Lock Disable**: Automatic configuration for uninterrupted sessions

### Optional DCV Components
- **Web Viewer**: Browser-based client (recommended)
- **Virtual Sessions**: Desktop session support (requires desktop environment)
- **GPU Support**: Hardware-accelerated graphics (x86_64 only)
- **External Authenticator**: For DCV EnginFrame integration
- **USB Remotization**: Specialized USB device forwarding
- **PulseAudio**: Microphone redirection support

## Configuration Options

Edit `dcv-install-config.sh` or set environment variables:

```bash
# Desktop Environment
export INSTALL_DESKTOP=true                    # Install desktop environment
export DESKTOP_ENVIRONMENT="ubuntu-desktop-minimal"  # Desktop type

# DCV Components
export INSTALL_WEB_VIEWER=true                 # Browser-based access
export INSTALL_VIRTUAL_SESSIONS=true           # Virtual desktop sessions
export INSTALL_GPU_SUPPORT=false               # GPU acceleration (x86_64 only)
export INSTALL_EXTERNAL_AUTH=false             # EnginFrame integration
export INSTALL_USB_REMOTIZATION=false          # USB device forwarding
export INSTALL_PULSEAUDIO=true                 # Microphone support

# System Configuration
export AUTO_START_SERVICE=true                 # Start on boot
export DISABLE_SCREENSAVER=true                # Disable screensaver
export DISABLE_LOCK_SCREEN=true                # Disable lock screen
```

## Post-Installation

### Accessing DCV Server

1. **Web Browser**: `https://YOUR_EC2_PUBLIC_IP:8443`
2. **DCV Client**: Download from [Amazon DCV website](https://download.amazondcv.com/)

### Session Types

The script creates two types of sessions:

1. **Console Session** (`$USER-console`): Direct access to the physical console
2. **Virtual Session** (`$USER-virtual`): Independent virtual desktop (requires desktop environment)

### Security Group Configuration

Ensure your EC2 security group allows:
- **Port 8443/TCP**: HTTPS access
- **Port 8443/UDP**: QUIC protocol (optional, for better performance)

Example security group rule:
```
Type: Custom TCP
Port: 8443
Source: Your IP address or 0.0.0.0/0 (less secure)
```

### Reboot Recommendation

After installing a desktop environment, **reboot the system** for optimal performance:

```bash
sudo reboot
```

## Desktop Environment Features

### Screensaver and Lock Screen

The script automatically configures the desktop to:
- Disable screensaver activation
- Disable automatic screen locking
- Disable display power management (DPMS)
- Prevent idle session timeouts

These settings are applied system-wide and for all users.

### Display Configuration

- **Maximum Resolution**: 4096x2160 (4K)
- **Multiple Monitors**: Supported
- **X11 Backend**: Wayland is disabled in favor of X11 for better DCV compatibility

### Performance Optimization

- **Memory Requirements**: Minimum 2.4GB RAM for desktop environments
- **Instance Types**: t3.medium or larger recommended
- **GPU Support**: Available for graphics-intensive workloads

## Useful Commands

### Service Management
```bash
# Check service status
sudo systemctl status dcvserver

# Start/stop service
sudo systemctl start dcvserver
sudo systemctl stop dcvserver

# Enable/disable auto-start
sudo systemctl enable dcvserver
sudo systemctl disable dcvserver

# View logs
sudo journalctl -u dcvserver -f
```

### Session Management
```bash
# List active sessions
dcv list-sessions

# Create a new console session
dcv create-session --type=console --owner=$USER my-console

# Create a virtual session (requires desktop environment)
dcv create-session --type=virtual --owner=$USER my-virtual

# Close a session
dcv close-session session-name

# Get session details
dcv describe-session session-name
```

### Desktop Configuration
```bash
# Check current desktop settings
gsettings list-recursively org.gnome.desktop.screensaver
gsettings list-recursively org.gnome.desktop.session

# Manually disable screensaver (if needed)
gsettings set org.gnome.desktop.screensaver lock-enabled false
gsettings set org.gnome.desktop.screensaver idle-activation-enabled false

# Check X11 display settings
xset q
```

### Configuration Files
- Main DCV config: `/etc/dcv/dcv.conf`
- Permissions config: `/etc/dcv/default.perm`
- Desktop config script: `/etc/profile.d/dcv-desktop-config.sh`
- Session config: `/etc/dcv/session-management/`

## Troubleshooting

### Common Issues

1. **Service won't start**:
   ```bash
   sudo journalctl -u dcvserver -n 50
   ```

2. **Can't connect via browser**:
   - Check security group allows port 8443
   - Verify service is running: `sudo systemctl status dcvserver`
   - Check firewall: `sudo ufw status`

3. **Virtual session creation fails**:
   - Ensure desktop environment is installed
   - Check if nice-xdcv package is installed
   - Verify user permissions: `groups $USER`
   - Check session logs: `/var/log/dcv/`

4. **Desktop doesn't load properly**:
   - Reboot the system after desktop installation
   - Check display manager: `sudo systemctl status gdm3`
   - Verify X11 is running: `echo $DISPLAY`

5. **Screensaver still activates**:
   - Check if settings were applied: `gsettings get org.gnome.desktop.screensaver lock-enabled`
   - Manually run: `source /etc/profile.d/dcv-desktop-config.sh`
   - Restart the session

6. **GPU not working**:
   - Verify GPU drivers are installed
   - Check if nice-dcv-gl package is installed
   - Run GL test: `dcvgltest` (if nice-dcv-gltest is installed)

7. **Low memory warnings**:
   - Upgrade to t3.medium or larger instance
   - Consider using ubuntu-desktop-minimal instead of full desktop
   - Monitor memory usage: `free -h`

### Log Locations
- Service logs: `sudo journalctl -u dcvserver`
- Session logs: `/var/log/dcv/`
- Server logs: `/var/log/dcv/server.log`
- Session launcher: `/var/log/dcv/sessionlauncher.log`
- X session errors: `~/.xsession-errors`

### Testing Virtual Sessions

Create a minimal test session:
```bash
# Create a simple init script
cat > /tmp/test-session.sh << 'EOF'
#!/bin/sh
metacity &
gnome-terminal
EOF

chmod +x /tmp/test-session.sh

# Create test session
dcv create-session test-session --init /tmp/test-session.sh
```

## Performance Optimization

### For Desktop Environments
- Use ubuntu-desktop-minimal for better performance
- Disable unnecessary services and animations
- Consider XFCE4 for very lightweight desktop experience

### For GPU Instances
- Install NVIDIA drivers before running the script
- Enable GPU support: `INSTALL_GPU_SUPPORT=true`
- Consider using G4dn, G5, or newer instance types

### For High-Resolution Displays
Edit `/etc/dcv/dcv.conf`:
```ini
[display]
# Set maximum resolution
max-head-resolution=4096x2160
```

### For Better Network Performance
- Use instances with Enhanced Networking
- Consider Placement Groups for low latency
- Enable QUIC protocol (UDP 8443)

## Integration with EC2 Spot Hibernation

This DCV installation script is designed to work with the EC2 Spot Hibernation workflow described in the main README. When used together:

1. DCV Server will automatically start after hibernation restoration
2. Desktop environment will be preserved during hibernation
3. Virtual sessions may need to be recreated after hibernation
4. Console sessions typically survive hibernation better than virtual sessions

### Hibernation Considerations

- **Console Sessions**: Generally survive hibernation/restoration cycles
- **Virtual Sessions**: May need to be recreated after hibernation
- **Desktop State**: User applications and desktop state are preserved
- **Service Startup**: DCV service auto-starts after hibernation restoration

## Security Considerations

1. **Use HTTPS**: DCV uses HTTPS by default (port 8443)
2. **Restrict Access**: Limit security group rules to specific IP ranges
3. **User Authentication**: DCV uses system users by default
4. **Session Isolation**: Each user gets isolated sessions
5. **Encryption**: All traffic is encrypted in transit
6. **Desktop Security**: Lock screen is disabled for convenience but consider security implications

## Desktop Environment Comparison

| Environment | Size | Performance | Features | Recommended For |
|-------------|------|-------------|----------|-----------------|
| ubuntu-desktop-minimal | ~2GB | Good | Essential apps | Most users |
| ubuntu-desktop | ~4GB | Moderate | Full suite | Feature-rich experience |
| gnome-session | ~1.5GB | Good | GNOME only | Minimal GNOME |
| xfce4 | ~1GB | Excellent | Lightweight | Low-resource instances |
| kde-plasma-desktop | ~3GB | Moderate | Feature-rich | KDE users |

## Support and Documentation

- [Amazon DCV User Guide](https://docs.aws.amazon.com/dcv/latest/userguide/)
- [Amazon DCV Administrator Guide](https://docs.aws.amazon.com/dcv/latest/adminguide/)
- [DCV Downloads](https://download.amazondcv.com/)
- [Ubuntu Desktop Guide](https://help.ubuntu.com/stable/ubuntu-help/)

## License

This script is provided under the same license as the parent project. Amazon DCV Server requires appropriate licensing for production use on non-EC2 instances.
