# Amazon DCV Ubuntu 25.04 Support

This directory contains tools and documentation for installing Amazon DCV Client on Ubuntu 25.04, which has newer library versions that may cause dependency conflicts with DCV packages built for older Ubuntu versions.

## Problem Description

Amazon DCV Client packages are typically built for older Ubuntu versions and depend on `libicu74`, while Ubuntu 25.04 ships with `libicu76`. This version mismatch prevents direct installation of the DCV client package.

## Solution: Dummy Package Creation

The recommended solution creates a compatibility package that satisfies the `libicu74` dependency by mapping it to the installed `libicu76`. This approach:

- ✅ Maintains clean package management
- ✅ Allows proper installation/removal of DCV client
- ✅ Preserves system integrity
- ✅ Works with package managers (apt, dpkg)
- ✅ Handles dependency resolution automatically

## Quick Start

1. **Download the Amazon DCV Client DEB package** for Ubuntu
2. **Create and install the dummy package**:
   ```bash
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

## How It Works

The dummy package (`libicu74`) provides the required dependency while actually depending on `libicu76`. When the DCV client requests `libicu74`, the system satisfies this with the dummy package, which ensures `libicu76` is available.

**Package relationship:**
```
DCV Client → requires libicu74 → dummy package → depends on libicu76 (installed)
```

## Compatibility Notes

- **libicu76 backward compatibility**: Generally compatible with libicu74 applications
- **ABI stability**: ICU maintains ABI compatibility within major versions
- **Symbol versioning**: Most applications work without issues

## Testing Checklist

After installation, verify:
- [ ] DCV Client launches without errors
- [ ] Connection to DCV servers works
- [ ] Audio/video streaming functions properly
- [ ] File transfer capabilities work
- [ ] No library loading errors in logs

## Troubleshooting

### Common Issues

1. **Package conflicts**: Use `apt --fix-broken install` to resolve
2. **Missing dependencies**: Install with `sudo apt install -f`
3. **Library not found**: Check symbolic links with `ldconfig -p | grep libicu`

### Verification Commands

```bash
# Check installed libicu version
dpkg -l | grep libicu

# Verify DCV client dependencies
dpkg -I your-dcv-client.deb | grep Depends

# Test library loading
ldd /usr/bin/dcvviewer | grep libicu
```

## Rollback Instructions

### If using repackaged DEB:
```bash
sudo dpkg -r dcv-client-package-name
```

### If using dummy package:
```bash
sudo dpkg -r dcv-client-package-name
sudo dpkg -r libicu74-dummy
```

### If using symbolic links:
```bash
sudo dpkg -r dcv-client-package-name
sudo rm /usr/lib/x86_64-linux-gnu/libicu.so.74*
```

## Advanced Usage

### Custom Dependency Mapping
Edit the repackaging script to handle other dependency conflicts:
- `libssl1.1` → `libssl3`
- `libcrypto1.1` → `libcrypto3`
- Other version-specific libraries

### Batch Processing
Process multiple DEB files:
```bash
for deb in *.deb; do
    ./repackage-dcv-client.sh "$deb"
done
```

## Security Considerations

- Verify package integrity before and after modification
- Test thoroughly in non-production environments
- Keep original packages for rollback
- Monitor for security updates from Amazon

## Contributing

If you encounter issues or have improvements:
1. Test your changes thoroughly
2. Document any new compatibility issues
3. Submit pull requests with clear descriptions
4. Include test cases for new scenarios

## Support

For Amazon DCV specific issues:
- [Amazon DCV Documentation](https://docs.aws.amazon.com/dcv/)
- [Amazon DCV User Guide](https://docs.aws.amazon.com/dcv/latest/userguide/)

For Ubuntu 25.04 specific issues:
- [Ubuntu Documentation](https://help.ubuntu.com/)
- [Ubuntu Community Support](https://askubuntu.com/)
