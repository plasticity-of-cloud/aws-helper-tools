# AWS Helper Tools

Increasing your productivity in AWS is like time to first byte, very useful.

## Tools Available

### Amazon DCV Server Installation

Automated installation scripts for Amazon DCV Server on Ubuntu systems.

**Location**: [`amazon-dcv/`](amazon-dcv/)

**Features**:
- Complete desktop environment installation (GNOME, XFCE4, KDE)
- Automatic screensaver and lock screen disabling
- Support for console and virtual sessions
- GPU acceleration support
- AWS EC2 optimized configuration
- Compatible with EC2 Spot Instance hibernation

**Quick Start**:
```bash
cd amazon-dcv
./install-dcv-ubuntu.sh
```

See [amazon-dcv/README.md](amazon-dcv/README.md) for detailed information.

### Kubernetes Development Tools

Comprehensive setup for Kubernetes operator development using Kubebuilder and Operator SDK.

**Location**: [`kubernetes_development/`](kubernetes_development/)

**Features**:
- Automated installation of Kubebuilder and Operator SDK (latest versions)
- Complete Go development environment setup
- Docker and Kubernetes toolchain (kubectl, kind, helm, kustomize)
- Ready-to-use workspace with documentation and examples
- Ubuntu 18.04+ compatibility with version detection
- Comprehensive verification and troubleshooting guides

**Quick Start**:
```bash
cd kubernetes_development
./install-k8s-operator-tools.sh
```

See [kubernetes_development/README.md](kubernetes_development/README.md) for detailed information.

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
