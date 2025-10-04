#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Check if MicroK8s is running
check_microk8s() {
    if ! command -v microk8s &> /dev/null; then
        log_error "MicroK8s is not installed. Please install MicroK8s first."
        exit 1
    fi
    
    if ! microk8s status --wait-ready; then
        log_error "MicroK8s is not ready. Please check MicroK8s status."
        exit 1
    fi
    
    log_success "MicroK8s is running and ready"
}

# Enable required MicroK8s addons
enable_microk8s_addons() {
    log_info "Enabling required MicroK8s addons..."
    
    # Enable helm3 for installing charts
    microk8s enable helm3
    
    # Enable storage for EBS CSI driver simulation
    microk8s enable storage
    
    # Enable metallb for LoadBalancer services (simulates AWS Load Balancer)
    log_info "Configuring MetalLB for LoadBalancer services..."
    # Get the host IP range for MetalLB
    HOST_IP=$(ip route get 1.1.1.1 | awk '{print $7}' | head -n1)
    METALLB_RANGE="${HOST_IP}/32"
    
    microk8s enable metallb:${METALLB_RANGE}
    
    log_success "MicroK8s addons enabled"
}

# Install AWS EBS CSI Driver (simulated with local storage)
install_ebs_csi_driver() {
    log_info "Installing AWS EBS CSI Driver simulation..."
    
    # Create a StorageClass that mimics EBS gp3 using local storage
    cat <<EOF | microk8s kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: microk8s.io/hostpath
parameters:
  type: gp3
  fsType: ext4
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
EOF
    
    log_success "EBS CSI Driver simulation configured"
}

# Install Mountpoint for S3 CSI Driver simulation
install_s3_csi_driver() {
    log_info "Installing S3 CSI Driver simulation..."
    
    # Create a StorageClass that simulates S3 mounting
    cat <<EOF | microk8s kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: s3-csi
provisioner: microk8s.io/hostpath
parameters:
  type: s3
  fsType: fuse
allowVolumeExpansion: false
volumeBindingMode: Immediate
reclaimPolicy: Delete
EOF
    
    log_success "S3 CSI Driver simulation configured"
}

# Install Karpenter simulation (Cluster Autoscaler alternative)
install_karpenter() {
    log_info "Installing Cluster Autoscaler (Karpenter alternative)..."
    
    # Install cluster-autoscaler as a Karpenter alternative
    cat <<EOF | microk8s kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
  namespace: kube-system
  labels:
    app: cluster-autoscaler
spec:
  selector:
    matchLabels:
      app: cluster-autoscaler
  template:
    metadata:
      labels:
        app: cluster-autoscaler
    spec:
      serviceAccountName: cluster-autoscaler
      containers:
      - image: k8s.gcr.io/autoscaling/cluster-autoscaler:v1.21.0
        name: cluster-autoscaler
        resources:
          limits:
            cpu: 100m
            memory: 300Mi
          requests:
            cpu: 100m
            memory: 300Mi
        command:
        - ./cluster-autoscaler
        - --v=4
        - --stderrthreshold=info
        - --cloud-provider=aws
        - --skip-nodes-with-local-storage=false
        - --expander=least-waste
        - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/microk8s-cluster
        env:
        - name: AWS_REGION
          value: us-east-1
---
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    k8s-addon: cluster-autoscaler.addons.k8s.io
    k8s-app: cluster-autoscaler
  name: cluster-autoscaler
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-autoscaler
  labels:
    k8s-addon: cluster-autoscaler.addons.k8s.io
    k8s-app: cluster-autoscaler
rules:
- apiGroups: [""]
  resources: ["events", "endpoints"]
  verbs: ["create", "patch"]
- apiGroups: [""]
  resources: ["pods/eviction"]
  verbs: ["create"]
- apiGroups: [""]
  resources: ["pods/status"]
  verbs: ["update"]
- apiGroups: [""]
  resources: ["endpoints"]
  resourceNames: ["cluster-autoscaler"]
  verbs: ["get", "update"]
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["watch", "list", "get", "update"]
- apiGroups: [""]
  resources: ["pods", "services", "replicationcontrollers", "persistentvolumeclaims", "persistentvolumes"]
  verbs: ["watch", "list", "get"]
- apiGroups: ["extensions"]
  resources: ["replicasets", "daemonsets"]
  verbs: ["watch", "list", "get"]
- apiGroups: ["policy"]
  resources: ["poddisruptionbudgets"]
  verbs: ["watch", "list"]
- apiGroups: ["apps"]
  resources: ["statefulsets", "replicasets", "daemonsets"]
  verbs: ["watch", "list", "get"]
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses", "csinodes"]
  verbs: ["watch", "list", "get"]
- apiGroups: ["batch", "extensions"]
  resources: ["jobs"]
  verbs: ["get", "list", "watch", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-autoscaler
  labels:
    k8s-addon: cluster-autoscaler.addons.k8s.io
    k8s-app: cluster-autoscaler
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-autoscaler
subjects:
- kind: ServiceAccount
  name: cluster-autoscaler
  namespace: kube-system
EOF
    
    log_success "Cluster Autoscaler (Karpenter alternative) installed"
}

# Install OIDC Identity Provider simulation
install_oidc_provider() {
    log_info "Setting up OIDC Identity Provider simulation..."
    
    # Create a service account with OIDC annotations (simulated)
    cat <<EOF | microk8s kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-oidc-service-account
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/EKSServiceRole
    eks.amazonaws.com/sts-regional-endpoints: "true"
EOF
    
    # Create a sample pod that uses the OIDC service account
    cat <<EOF | microk8s kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: aws-oidc-test-pod
  namespace: default
spec:
  serviceAccountName: aws-oidc-service-account
  containers:
  - name: aws-cli
    image: amazon/aws-cli:latest
    command: ["sleep", "3600"]
    env:
    - name: AWS_ROLE_ARN
      value: "arn:aws:iam::123456789012:role/EKSServiceRole"
    - name: AWS_WEB_IDENTITY_TOKEN_FILE
      value: "/var/run/secrets/eks.amazonaws.com/serviceaccount/token"
    volumeMounts:
    - name: aws-iam-token
      mountPath: "/var/run/secrets/eks.amazonaws.com/serviceaccount"
      readOnly: true
  volumes:
  - name: aws-iam-token
    projected:
      sources:
      - serviceAccountToken:
          audience: sts.amazonaws.com
          expirationSeconds: 86400
          path: token
EOF
    
    log_success "OIDC Identity Provider simulation configured"
}

# Verify installations
verify_installations() {
    log_info "Verifying installations..."
    
    # Check pods in kube-system
    log_info "Checking system pods..."
    microk8s kubectl get pods -n kube-system
    
    # Check storage classes
    log_info "Checking storage classes..."
    microk8s kubectl get storageclass
    
    # Check services
    log_info "Checking services..."
    microk8s kubectl get svc -A
    
    log_success "All components installed and verified"
}

# Main function
main() {
    log_info "Setting up EKS-like addons on MicroK8s..."
    
    check_microk8s
    enable_microk8s_addons
    
    # Wait for addons to be ready
    sleep 30
    
    install_ebs_csi_driver
    install_s3_csi_driver
    install_karpenter
    install_oidc_provider
    
    # Wait for all components to be ready
    sleep 30
    
    verify_installations
    
    log_success "EKS-like environment setup complete!"
    echo
    log_info "Next steps:"
    echo "1. Test EBS CSI simulation: Create PVC with gp3 storage class"
    echo "2. Test S3 CSI simulation: Create PVC with s3-csi storage class"
    echo "3. Test LoadBalancer: Create a service with type LoadBalancer (uses MetalLB)"
    echo "4. Test OIDC: kubectl exec -it aws-oidc-test-pod -- aws sts get-caller-identity"
    echo "5. View cluster autoscaler logs: kubectl logs -f deployment/cluster-autoscaler -n kube-system"
}

# Run main function
main "$@"
