# Kubernetes Development Tools

This directory contains tools and scripts for Kubernetes development, specifically focused on operator development using Kubebuilder and Operator SDK.

## 🚀 Quick Start

```bash
cd kubernetes_development
./install-k8s-operator-tools.sh
```

## 📋 What's Included

### Installation Script: `install-k8s-operator-tools.sh`

Automated installation script that sets up a complete Kubernetes operator development environment on Ubuntu systems.

#### Core Tools Installed

| Tool | Latest Version | Purpose |
|------|----------------|---------|
| **Kubebuilder** | v4.9.0 | Framework for building Kubernetes APIs using CRDs |
| **Operator SDK** | v1.41.1 | SDK for building Kubernetes operators |
| **Go** | Latest | Required runtime for operator development |
| **Docker** | Latest | Container runtime for building and testing |
| **kubectl** | Latest | Kubernetes command-line tool |

#### Additional Development Tools

| Tool | Purpose |
|------|---------|
| **kustomize** | Kubernetes configuration management |
| **Helm** | Kubernetes package manager |
| **kind** | Kubernetes in Docker for local testing |

## 🔧 Installation Details

### System Requirements

- **Operating System**: Ubuntu 18.04, 20.04, 22.04, or 24.04
- **Architecture**: x86_64 (amd64) or ARM64 (aarch64)
- **User**: Non-root user with sudo privileges
- **Internet**: Required for downloading packages

### What the Script Does

1. **System Validation**
   - Checks Ubuntu version compatibility
   - Ensures non-root execution
   - Validates system architecture (amd64/arm64)

2. **Prerequisites Installation**
   - Updates package repositories
   - Installs build tools and dependencies
   - Configures package signing keys

3. **Go Installation**
   - Detects existing Go installation
   - Installs latest Go version if needed
   - Configures GOPATH and PATH variables

4. **Container Runtime Setup**
   - Installs Docker CE with latest plugins
   - Adds user to docker group
   - Configures Docker repository

5. **Kubernetes Tools**
   - Installs kubectl (latest stable)
   - Downloads and installs Kubebuilder
   - Downloads and installs Operator SDK

6. **Development Tools**
   - Installs kustomize for configuration management
   - Installs Helm for package management
   - Installs kind for local cluster testing

7. **Environment Setup**
   - Creates sample workspace directory
   - Generates starter documentation
   - Configures shell environment

## 📖 Usage Guide

### Running the Installation

```bash
# Clone the repository (if not already done)
git clone <repository-url>
cd aws-helper-tools/kubernetes_development

# Make script executable (if needed)
chmod +x install-k8s-operator-tools.sh

# Run the installation
./install-k8s-operator-tools.sh
```

### Post-Installation Setup

1. **Refresh Your Environment**
   ```bash
   # Option 1: Source bashrc
   source ~/.bashrc
   
   # Option 2: Log out and log back in
   # Option 3: Start new terminal session
   ```

2. **Verify Docker Access**
   ```bash
   # Test Docker without sudo
   docker --version
   
   # If permission denied, run:
   newgrp docker
   ```

3. **Create Local Test Cluster**
   ```bash
   # Create a kind cluster for testing
   kind create cluster --name dev-cluster
   
   # Verify cluster access
   kubectl cluster-info
   ```

### Development Workflows

#### Using Kubebuilder

```bash
# Navigate to workspace
cd ~/k8s-operator-workspace

# Initialize new project
kubebuilder init --domain mycompany.com --repo github.com/mycompany/my-operator

# Create API and controller
kubebuilder create api --group webapp --version v1 --kind Guestbook --resource --controller

# Generate manifests
make manifests

# Run locally (against configured cluster)
make run

# Build and load into kind cluster
make docker-build IMG=my-operator:dev
kind load docker-image my-operator:dev --name dev-cluster

# Deploy to cluster
make deploy IMG=my-operator:dev
```

#### Using Operator SDK

```bash
# Navigate to workspace
cd ~/k8s-operator-workspace

# Initialize Go-based operator
operator-sdk init --domain mycompany.com --repo github.com/mycompany/my-operator

# Create API and controller
operator-sdk create api --group cache --version v1 --kind Memcached --resource --controller

# Generate manifests
make manifests

# Run locally
make run

# Build and deploy
make docker-build docker-push IMG=my-operator:dev
make deploy IMG=my-operator:dev
```

## 🛠️ Development Environment

### Workspace Structure

After installation, you'll find a ready-to-use workspace at `~/k8s-operator-workspace/`:

```
~/k8s-operator-workspace/
├── README.md              # Quick start guide
└── (your projects here)   # Created by kubebuilder/operator-sdk
```

### Environment Variables

The script automatically configures:

```bash
export PATH=$PATH:/usr/local/go/bin
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin
```

### Useful Commands

| Command | Purpose |
|---------|---------|
| `kubectl cluster-info` | Check cluster connection |
| `kind create cluster` | Create local test cluster |
| `kind delete cluster` | Delete local test cluster |
| `make run` | Run operator locally |
| `make docker-build` | Build operator container |
| `make deploy` | Deploy to cluster |
| `make undeploy` | Remove from cluster |
| `kubectl get crd` | List custom resources |
| `kubectl logs -f deployment/controller-manager -n system` | View operator logs |

## 🔍 Troubleshooting

### Common Issues

#### Permission Denied for Docker
```bash
# Add user to docker group and refresh
sudo usermod -aG docker $USER
newgrp docker
```

#### Go Command Not Found
```bash
# Source bashrc or restart terminal
source ~/.bashrc
```

#### Kubebuilder/Operator SDK Not Found
```bash
# Check if /usr/local/bin is in PATH
echo $PATH | grep -o /usr/local/bin

# If not found, add to PATH
export PATH=$PATH:/usr/local/bin
```

#### Kind Cluster Creation Fails
```bash
# Check Docker is running
sudo systemctl status docker

# Start Docker if needed
sudo systemctl start docker
```

### Version Verification

```bash
# Check all installed versions
go version
docker --version
kubectl version --client
kubebuilder version
operator-sdk version
kustomize version
helm version
kind version
```

## 📚 Learning Resources

### Official Documentation
- [Kubebuilder Book](https://book.kubebuilder.io/) - Comprehensive guide to Kubebuilder
- [Operator SDK Documentation](https://sdk.operatorframework.io/) - Complete Operator SDK guide
- [Kubernetes API Reference](https://kubernetes.io/docs/reference/kubernetes-api/) - API documentation
- [Custom Resource Definitions](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/) - CRD concepts

### Tutorials and Examples
- [Kubebuilder Tutorial](https://book.kubebuilder.io/cronjob-tutorial/cronjob-tutorial.html) - Step-by-step tutorial
- [Operator SDK Tutorial](https://sdk.operatorframework.io/docs/building-operators/golang/tutorial/) - Go operator tutorial
- [Operator Hub](https://operatorhub.io/) - Community operators for reference

### Best Practices
- [Operator Best Practices](https://sdk.operatorframework.io/docs/best-practices/) - Development guidelines
- [Kubernetes Operator Patterns](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/) - Design patterns
- [Controller Runtime](https://pkg.go.dev/sigs.k8s.io/controller-runtime) - Runtime library documentation

## 🤝 Contributing

Contributions to improve the installation script or documentation are welcome! Please:

1. Test changes on supported Ubuntu versions
2. Update documentation for any new features
3. Follow existing code style and conventions
4. Add appropriate error handling and logging

## 📄 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](../LICENSE) file for details.

## 🆘 Support

For issues related to:
- **Installation script**: Open an issue in this repository
- **Kubebuilder**: Check [Kubebuilder GitHub Issues](https://github.com/kubernetes-sigs/kubebuilder/issues)
- **Operator SDK**: Check [Operator SDK GitHub Issues](https://github.com/operator-framework/operator-sdk/issues)
- **Kubernetes**: Check [Kubernetes Documentation](https://kubernetes.io/docs/home/)
