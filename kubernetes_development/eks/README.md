# Kubernetes Development with EKS

This directory contains scripts and configurations for setting up Kubernetes clusters for development purposes.

## Available Options

### 1. Simple EKS Cluster (New)
A straightforward single-AZ EKS cluster with essential add-ons for development.

**Features:**
- Single availability zone deployment
- EBS CSI driver for persistent storage
- AWS Load Balancer Controller for ALB/NLB
- Managed node group with auto-scaling
- OIDC provider for service accounts

**Usage:**
```bash
# Create cluster (default: simple-eks-cluster in eu-west-1a)
./setup-simple-eks.sh

# Create with custom parameters
./setup-simple-eks.sh my-cluster eu-west-2 t3.large 3

# Test with sample application
kubectl apply -f sample-app-with-storage.yaml

# Cleanup
./cleanup-simple-eks.sh
```

### 2. Single Node Kops (Existing)
Lightweight single-node Kubernetes cluster using kops.

**Usage:**
```bash
./install-kops-tools.sh
./setup-single-node-kops.sh
```

## Quick Start - Simple EKS

1. **Setup cluster:**
   ```bash
   ./setup-simple-eks.sh
   ```

2. **Deploy sample app with storage and ALB:**
   ```bash
   kubectl apply -f sample-app-with-storage.yaml
   ```

3. **Check resources:**
   ```bash
   kubectl get pods,pvc,ingress
   kubectl get nodes
   ```

4. **Get ALB URL:**
   ```bash
   kubectl get ingress sample-app-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
   ```

5. **Cleanup:**
   ```bash
   ./cleanup-simple-eks.sh
   ```

## Configuration Details

### Simple EKS Cluster Specs
- **Control Plane:** Managed by AWS EKS
- **Nodes:** Managed node group in single AZ
- **Storage:** EBS CSI driver with gp3 volumes
- **Load Balancing:** AWS Load Balancer Controller
- **Networking:** VPC CNI with default settings
- **Instance Types:** Configurable (default: t3.medium)

### Add-ons Included
- `aws-ebs-csi-driver` - For persistent volumes
- `aws-load-balancer-controller` - For ALB/NLB ingress

### IAM Permissions
The cluster includes proper IAM roles for:
- EBS volume management
- ALB/NLB creation and management
- Auto-scaling operations
- OIDC-based service account authentication

## Cost Considerations

**Simple EKS Cluster:**
- EKS Control Plane: ~$73/month
- Worker Nodes: Variable based on instance type and count
- EBS Volumes: ~$0.10/GB/month
- Load Balancers: ~$16/month per ALB

**Estimated monthly cost for development:**
- Control Plane: $73
- 2x t3.medium nodes: ~$60
- Storage (20GB per node): ~$4
- **Total: ~$137/month**

## Cleanup

Always clean up resources when done to avoid charges:

```bash
# Simple EKS
./cleanup-simple-eks.sh

# Kops
kops delete cluster --name=development.k8s.local --yes
```

## Troubleshooting

### Common Issues

1. **ALB not creating:**
   - Check AWS Load Balancer Controller logs
   - Verify IAM permissions
   - Ensure subnets are tagged correctly

2. **EBS volumes not mounting:**
   - Check EBS CSI driver status
   - Verify node IAM permissions
   - Check storage class configuration

3. **Nodes not joining:**
   - Check security group rules
   - Verify subnet configuration
   - Check IAM roles

### Useful Commands

```bash
# Check cluster status
eksctl get cluster

# Check add-ons
eksctl get addons --cluster simple-eks-cluster

# Check node group
eksctl get nodegroup --cluster simple-eks-cluster

# Update kubeconfig
aws eks update-kubeconfig --region eu-west-1 --name simple-eks-cluster
```
