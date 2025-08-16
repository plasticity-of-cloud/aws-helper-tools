# Kubernetes Operator Development - Quick Reference

## 🚀 Installation

```bash
cd kubernetes_development
./install-k8s-operator-tools.sh
source ~/.bashrc
```

## 🔧 Setup Local Cluster

```bash
# Create kind cluster
kind create cluster --name dev-cluster

# Verify
kubectl cluster-info
kubectl get nodes
```

## 📦 Kubebuilder Workflow

```bash
# 1. Initialize project
kubebuilder init --domain example.com --repo github.com/user/project

# 2. Create API
kubebuilder create api --group webapp --version v1 --kind MyApp --resource --controller

# 3. Edit types (api/v1/myapp_types.go)
# 4. Edit controller (controllers/myapp_controller.go)

# 5. Generate code
make generate
make manifests

# 6. Test locally
make run

# 7. Build and deploy
make docker-build IMG=myapp:dev
kind load docker-image myapp:dev --name dev-cluster
make deploy IMG=myapp:dev
```

## 🛠️ Operator SDK Workflow

```bash
# 1. Initialize project
operator-sdk init --domain example.com --repo github.com/user/project

# 2. Create API
operator-sdk create api --group cache --version v1 --kind Memcached --resource --controller

# 3. Edit types and controller (same as Kubebuilder)

# 4. Generate and deploy
make manifests generate
make run
make docker-build docker-push IMG=memcached:dev
make deploy IMG=memcached:dev
```

## 🔍 Common Commands

### Cluster Management
```bash
kind create cluster --name <name>          # Create cluster
kind delete cluster --name <name>          # Delete cluster
kind get clusters                          # List clusters
kubectl config get-contexts               # List contexts
kubectl config use-context <context>      # Switch context
```

### Development
```bash
make run                                   # Run locally
make docker-build IMG=<image>             # Build image
make deploy IMG=<image>                    # Deploy to cluster
make undeploy                              # Remove from cluster
make install                               # Install CRDs
make uninstall                             # Remove CRDs
```

### Debugging
```bash
kubectl get crd                            # List custom resources
kubectl describe crd <crd-name>            # Describe CRD
kubectl get <resource> -A                  # List custom resources
kubectl logs -f deployment/controller-manager -n <namespace>  # Controller logs
kubectl describe <resource> <name>         # Resource details
```

## 📁 Project Structure

```
my-operator/
├── api/v1/                    # API definitions
│   ├── myapp_types.go         # Custom resource types
│   └── groupversion_info.go   # Group version info
├── controllers/               # Controllers
│   ├── myapp_controller.go    # Main controller logic
│   └── suite_test.go          # Test suite
├── config/                    # Kubernetes manifests
│   ├── crd/                   # CRD definitions
│   ├── rbac/                  # RBAC permissions
│   ├── manager/               # Manager deployment
│   └── samples/               # Sample resources
├── main.go                    # Entry point
├── Makefile                   # Build automation
├── Dockerfile                 # Container image
└── PROJECT                    # Project metadata
```

## 🎯 Key Files to Edit

1. **`api/v1/*_types.go`** - Define your custom resource structure
2. **`controllers/*_controller.go`** - Implement reconciliation logic
3. **`config/samples/`** - Create example resources for testing
4. **`config/rbac/`** - Adjust permissions if needed

## 🔄 Development Cycle

1. **Edit** types and controller logic
2. **Generate** code: `make generate manifests`
3. **Test** locally: `make run`
4. **Build** image: `make docker-build IMG=myapp:dev`
5. **Load** to kind: `kind load docker-image myapp:dev`
6. **Deploy**: `make deploy IMG=myapp:dev`
7. **Test** in cluster: `kubectl apply -f config/samples/`
8. **Debug**: Check logs and resource status
9. **Iterate**: Repeat from step 1

## 🐛 Troubleshooting

### Controller Not Starting
```bash
# Check manager logs
kubectl logs -f deployment/controller-manager -n system

# Check RBAC permissions
kubectl auth can-i '*' '*' --as=system:serviceaccount:system:controller-manager
```

### CRD Issues
```bash
# Reinstall CRDs
make uninstall install

# Check CRD status
kubectl get crd
kubectl describe crd <crd-name>
```

### Image Issues
```bash
# Verify image in kind
docker exec -it dev-cluster-control-plane crictl images

# Reload image
kind load docker-image <image> --name dev-cluster
```

## 📚 Essential Resources

- [Kubebuilder Book](https://book.kubebuilder.io/)
- [Operator SDK Docs](https://sdk.operatorframework.io/)
- [Controller Runtime](https://pkg.go.dev/sigs.k8s.io/controller-runtime)
- [Kubernetes API Conventions](https://github.com/kubernetes/community/blob/master/contributors/devel/sig-architecture/api-conventions.md)
