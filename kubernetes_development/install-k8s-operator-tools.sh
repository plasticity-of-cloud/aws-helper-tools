#!/bin/bash

# Kubernetes Operator SDK and Kubebuilder Installation Script for Ubuntu
# This script installs the latest versions of Operator SDK and Kubebuilder
# Compatible with Ubuntu 18.04, 20.04, 22.04, and 24.04

set -euo pipefail

# Architecture variable (will be set by detect_architecture function)
ARCH=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root. Please run as a regular user with sudo privileges."
        exit 1
    fi
}

# Check Ubuntu version and architecture
check_ubuntu() {
    if ! grep -q "Ubuntu" /etc/os-release; then
        log_error "This script is designed for Ubuntu systems only."
        exit 1
    fi
    
    local ubuntu_version=$(lsb_release -rs)
    log_info "Detected Ubuntu version: $ubuntu_version"
    
    if [[ ! "$ubuntu_version" =~ ^(18\.04|20\.04|22\.04|24\.04) ]]; then
        log_warning "This script has been tested on Ubuntu 18.04, 20.04, 22.04, and 24.04. Your version ($ubuntu_version) may not be fully supported."
    fi
}

# Detect system architecture
detect_architecture() {
    local arch=$(uname -m)
    case $arch in
        x86_64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        *)
            log_error "Unsupported architecture: $arch. Only amd64 and arm64 are supported."
            exit 1
            ;;
    esac
    log_info "Detected architecture: $ARCH"
}

# Install prerequisites
install_prerequisites() {
    log_info "Installing prerequisites..."
    
    sudo apt-get update
    sudo apt-get install -y \
        curl \
        wget \
        git \
        build-essential \
        unzip \
        jq \
        ca-certificates \
        gnupg \
        lsb-release
    
    log_success "Prerequisites installed successfully"
}

# Install Go if not present or version is too old
install_go() {
    local required_go_version="1.21"
    local go_version=""
    
    if command -v go &> /dev/null; then
        go_version=$(go version | grep -oP 'go\K[0-9]+\.[0-9]+')
        log_info "Found Go version: $go_version"
        
        # Compare versions (simplified comparison for major.minor)
        if [[ "$(printf '%s\n' "$required_go_version" "$go_version" | sort -V | head -n1)" == "$required_go_version" ]]; then
            log_success "Go version $go_version meets requirements (>= $required_go_version)"
            return 0
        else
            log_warning "Go version $go_version is too old. Installing latest Go..."
        fi
    else
        log_info "Go not found. Installing latest Go..."
    fi
    
    # Get latest Go version
    local latest_go=$(curl -s https://go.dev/VERSION?m=text|head -n1)
    local go_url="https://go.dev/dl/${latest_go}.linux-${ARCH}.tar.gz"
    
    log_info "Downloading Go ${latest_go}..."
    wget -q "$go_url" -O /tmp/go.tar.gz
    
    # Remove existing Go installation
    sudo rm -rf /usr/local/go
    
    # Install Go
    sudo tar -C /usr/local -xzf /tmp/go.tar.gz
    rm /tmp/go.tar.gz
    
    # Add Go to PATH if not already present
    if ! grep -q "/usr/local/go/bin" ~/.bashrc; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
        echo 'export GOPATH=$HOME/go' >> ~/.bashrc
        echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.bashrc
    fi
    
    # Source the changes for current session
    export PATH=$PATH:/usr/local/go/bin
    export GOPATH=$HOME/go
    export PATH=$PATH:$GOPATH/bin
    
    # Create GOPATH directory
    mkdir -p "$HOME/go/bin"
    
    log_success "Go ${latest_go} installed successfully"
}

# Install Docker if not present
install_docker() {
    if command -v docker &> /dev/null; then
        log_info "Docker is already installed"
        return 0
    fi
    
    log_info "Installing Docker..."
    
    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Add Docker repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    log_success "Docker installed successfully"
    log_warning "Please log out and log back in for Docker group membership to take effect"
}

# Install kubectl if not present
install_kubectl() {
    if command -v kubectl &> /dev/null; then
        log_info "kubectl is already installed"
        return 0
    fi
    
    log_info "Installing kubectl..."
    
    # Download kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl"
    
    # Install kubectl
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
    
    log_success "kubectl installed successfully"
}

# Install Kubebuilder
install_kubebuilder() {
    log_info "Installing Kubebuilder..."
    
    # Get latest version
    local latest_version=$(curl -s https://api.github.com/repos/kubernetes-sigs/kubebuilder/releases/latest | jq -r '.tag_name')
    log_info "Latest Kubebuilder version: $latest_version"
    
    # Download and install
    local download_url="https://github.com/kubernetes-sigs/kubebuilder/releases/download/${latest_version}/kubebuilder_linux_${ARCH}"
    
    curl -L "$download_url" -o /tmp/kubebuilder
    chmod +x /tmp/kubebuilder
    sudo mv /tmp/kubebuilder /usr/local/bin/
    
    log_success "Kubebuilder $latest_version installed successfully"
}

# Install Operator SDK
install_operator_sdk() {
    log_info "Installing Operator SDK..."
    
    # Get latest version
    local latest_version=$(curl -s https://api.github.com/repos/operator-framework/operator-sdk/releases/latest | jq -r '.tag_name')
    log_info "Latest Operator SDK version: $latest_version"
    
    # Download and install
    local download_url="https://github.com/operator-framework/operator-sdk/releases/download/${latest_version}/operator-sdk_linux_${ARCH}"
    
    curl -L "$download_url" -o /tmp/operator-sdk
    chmod +x /tmp/operator-sdk
    sudo mv /tmp/operator-sdk /usr/local/bin/
    
    log_success "Operator SDK $latest_version installed successfully"
}

# Install additional useful tools
install_additional_tools() {
    log_info "Installing additional useful tools..."
    
    # Install kustomize
    if ! command -v kustomize &> /dev/null; then
        log_info "Installing kustomize..."
        curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
        sudo mv kustomize /usr/local/bin/
        log_success "kustomize installed"
    fi
    
    # Install helm
    if ! command -v helm &> /dev/null; then
        log_info "Installing Helm..."
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
        log_success "Helm installed"
    fi
    
    # Install kind (Kubernetes in Docker)
    if ! command -v kind &> /dev/null; then
        log_info "Installing kind..."
        local kind_version=$(curl -s https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | jq -r '.tag_name')
        curl -Lo /tmp/kind "https://kind.sigs.k8s.io/dl/${kind_version}/kind-linux-${ARCH}"
        chmod +x /tmp/kind
        sudo mv /tmp/kind /usr/local/bin/
        log_success "kind installed"
    fi
}

# Verify installations
verify_installations() {
    log_info "Verifying installations..."
    
    local tools=("go" "docker" "kubectl" "kubebuilder" "operator-sdk" "kustomize" "helm" "kind")
    local failed_tools=()
    
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            local version=$($tool version 2>/dev/null | head -n1 || echo "version info not available")
            log_success "$tool: $version"
        else
            log_error "$tool: not found"
            failed_tools+=("$tool")
        fi
    done
    
    if [ ${#failed_tools[@]} -eq 0 ]; then
        log_success "All tools installed successfully!"
    else
        log_error "The following tools failed to install: ${failed_tools[*]}"
        return 1
    fi
}

# Create sample project structure
create_sample_project() {
    log_info "Creating sample project structure..."
    
    local project_dir="$HOME/k8s-operator-workspace"
    mkdir -p "$project_dir"
    
    cat > "$project_dir/README.md" << 'EOF'
# Kubernetes Operator Development Workspace

This directory is set up for Kubernetes operator development using Kubebuilder and Operator SDK.

## Quick Start with Kubebuilder

```bash
# Initialize a new project
kubebuilder init --domain example.com --repo github.com/example/my-operator

# Create a new API
kubebuilder create api --group webapp --version v1 --kind Guestbook

# Build and run locally
make run
```

## Quick Start with Operator SDK

```bash
# Initialize a new Go-based operator
operator-sdk init --domain example.com --repo github.com/example/my-operator

# Create a new API and controller
operator-sdk create api --group cache --version v1 --kind Memcached --resource --controller

# Build and run locally
make run
```

## Useful Commands

- `kubectl cluster-info` - Check cluster connection
- `kind create cluster` - Create local test cluster
- `make docker-build` - Build operator image
- `make deploy` - Deploy to cluster
- `make undeploy` - Remove from cluster

## Resources

- [Kubebuilder Documentation](https://book.kubebuilder.io/)
- [Operator SDK Documentation](https://sdk.operatorframework.io/)
- [Kubernetes API Reference](https://kubernetes.io/docs/reference/kubernetes-api/)
EOF
    
    log_success "Sample project structure created at $project_dir"
}

# Main installation function
main() {
    log_info "Starting Kubernetes Operator SDK and Kubebuilder installation..."
    log_info "This script will install the latest versions of both tools along with prerequisites"
    
    check_root
    check_ubuntu
    detect_architecture
    
    # Install components
    install_prerequisites
    install_go
    install_docker
    install_kubectl
    install_kubebuilder
    install_operator_sdk
    install_additional_tools
    
    # Verify and create sample project
    verify_installations
    create_sample_project
    
    log_success "Installation completed successfully!"
    echo
    log_info "Next steps:"
    echo "1. Log out and log back in (or run 'newgrp docker') to use Docker without sudo"
    echo "2. Source your bashrc: source ~/.bashrc"
    echo "3. Check the sample workspace at ~/k8s-operator-workspace"
    echo "4. Create a test cluster: kind create cluster"
    echo "5. Start developing your operators!"
    echo
    log_info "Installed versions:"
    echo "- Go: $(go version 2>/dev/null || echo 'Please source ~/.bashrc first')"
    echo "- Kubebuilder: $(kubebuilder version 2>/dev/null || echo 'Installation may need PATH refresh')"
    echo "- Operator SDK: $(operator-sdk version 2>/dev/null || echo 'Installation may need PATH refresh')"
}

# Run main function
main "$@"
