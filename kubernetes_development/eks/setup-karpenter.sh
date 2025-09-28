#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Load cluster environment
if [ -f cluster-env.sh ]; then
    source cluster-env.sh
else
    echo -e "${RED}cluster-env.sh not found. Run setup-local-kops-cluster.sh first${NC}"
    exit 1
fi

CLUSTER_NAME="${KOPS_CLUSTER_NAME}"
REGION="${1:-eu-west-1}"

echo -e "${GREEN}=== Setting up Karpenter for Local Kops Cluster ===${NC}"
echo -e "${GREEN}Cluster Name: $CLUSTER_NAME${NC}"
echo -e "${GREEN}Region: $REGION${NC}"

# Install Karpenter
echo -e "${YELLOW}Installing Karpenter...${NC}"
helm repo add karpenter https://charts.karpenter.sh/
helm repo update

# Create Karpenter namespace
kubectl create namespace karpenter || true

# Install Karpenter
helm upgrade --install karpenter karpenter/karpenter \
  --version "0.37.0" \
  --namespace karpenter \
  --create-namespace \
  --set "settings.clusterName=${CLUSTER_NAME}" \
  --set "settings.interruptionQueue=${CLUSTER_NAME}" \
  --set controller.resources.requests.cpu=1 \
  --set controller.resources.requests.memory=1Gi \
  --set controller.resources.limits.cpu=1 \
  --set controller.resources.limits.memory=1Gi

# Wait for Karpenter to be ready
echo -e "${YELLOW}Waiting for Karpenter to be ready...${NC}"
kubectl wait --for=condition=Available deployment/karpenter -n karpenter --timeout=300s

# Create NodePool
echo -e "${YELLOW}Creating Karpenter NodePool...${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64", "arm64"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]
        - key: node.kubernetes.io/instance-type
          operator: In
          values: ["t3.medium", "t3.large", "t4g.medium", "t4g.large"]
      nodeClassRef:
        apiVersion: karpenter.k8s.aws/v1beta1
        kind: EC2NodeClass
        name: default
      taints:
        - key: karpenter.sh/unschedulable
          value: "true"
          effect: NoSchedule
  limits:
    cpu: 1000
  disruption:
    consolidationPolicy: WhenUnderutilized
    consolidateAfter: 30s
    expireAfter: 30m
---
apiVersion: karpenter.k8s.aws/v1beta1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiFamily: AL2
  subnetSelectorTerms:
    - tags:
        kops.k8s.io/instancegroup: nodes
  securityGroupSelectorTerms:
    - tags:
        kubernetes.io/cluster/${CLUSTER_NAME}: owned
  instanceStorePolicy: RAID0
  userData: |
    #!/bin/bash
    /etc/eks/bootstrap.sh ${CLUSTER_NAME}
    echo "net.ipv4.conf.all.max_dgram_qlen = 30" >> /etc/sysctl.conf
    sysctl -p /etc/sysctl.conf
EOF

echo -e "${GREEN}=== Karpenter Setup Complete ===${NC}"

echo -e "${YELLOW}Verifying Karpenter installation...${NC}"
kubectl get pods -n karpenter
kubectl get nodepool
kubectl get ec2nodeclass

echo -e "${GREEN}=== Test Karpenter ===${NC}"
echo -e "${YELLOW}Deploy a test workload to trigger node provisioning:${NC}"
cat <<EOF
kubectl apply -f - <<EOL
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inflate
spec:
  replicas: 5
  selector:
    matchLabels:
      app: inflate
  template:
    metadata:
      labels:
        app: inflate
    spec:
      terminationGracePeriodSeconds: 0
      containers:
      - name: inflate
        image: public.ecr.aws/eks-distro/kubernetes/pause:3.7
        resources:
          requests:
            cpu: 1
            memory: 1.5Gi
EOL
EOF

echo -e "${YELLOW}Watch nodes being provisioned:${NC}"
echo -e "kubectl get nodes -w"
