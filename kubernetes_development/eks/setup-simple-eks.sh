#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
CLUSTER_NAME="${1:-simple-eks-cluster}"
REGION="${2:-eu-west-1}"
AZ="${REGION}a"
NODE_TYPE="${3:-t3.medium}"
NODE_COUNT="${4:-2}"

echo -e "${GREEN}=== Setting up Simple EKS Cluster ===${NC}"
echo -e "${GREEN}Cluster Name: $CLUSTER_NAME${NC}"
echo -e "${GREEN}Region: $REGION${NC}"
echo -e "${GREEN}Availability Zone: $AZ${NC}"
echo -e "${GREEN}Node Type: $NODE_TYPE${NC}"
echo -e "${GREEN}Node Count: $NODE_COUNT${NC}"

# Check if eksctl is installed
if ! command -v eksctl &> /dev/null; then
    echo -e "${YELLOW}Installing eksctl...${NC}"
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        *) echo -e "${RED}Unsupported architecture: $ARCH${NC}"; exit 1 ;;
    esac
    curl --silent --location "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname -s)_${ARCH}.tar.gz" | tar xz -C /tmp
    sudo mv /tmp/eksctl /usr/local/bin
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${YELLOW}Installing kubectl...${NC}"
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        *) echo -e "${RED}Unsupported architecture: $ARCH${NC}"; exit 1 ;;
    esac
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
fi

# Create cluster configuration
cat > simple-eks-config.yaml << EOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: ${CLUSTER_NAME}
  region: ${REGION}

availabilityZones: ["${AZ}"]

managedNodeGroups:
  - name: simple-nodes
    instanceType: ${NODE_TYPE}
    desiredCapacity: ${NODE_COUNT}
    minSize: 1
    maxSize: 5
    availabilityZones: ["${AZ}"]
    volumeSize: 20
    volumeType: gp3
    amiFamily: AmazonLinux2023
    iam:
      withAddonPolicies:
        ebs: true
        albIngress: true
        autoScaler: true

addons:
  - name: aws-ebs-csi-driver
    version: latest
  - name: coredns
    version: latest
  - name: kube-proxy
    version: latest
  - name: vpc-cni
    version: latest

iam:
  withOIDC: true
EOF

echo -e "${YELLOW}Creating EKS cluster...${NC}"
eksctl create cluster -f simple-eks-config.yaml

echo -e "${GREEN}=== Cluster Setup Complete ===${NC}"
echo -e "${GREEN}Cluster Name: $CLUSTER_NAME${NC}"
echo -e "${GREEN}Region: $REGION${NC}"

echo -e "${YELLOW}Verifying cluster...${NC}"
kubectl get nodes
kubectl get pods -n kube-system

echo -e "${GREEN}=== Next Steps ===${NC}"
echo -e "${YELLOW}1. Install AWS Load Balancer Controller (optional):${NC}"
echo -e "   eksctl create iamserviceaccount --cluster=${CLUSTER_NAME} --namespace=kube-system --name=aws-load-balancer-controller --attach-policy-arn=arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess --approve"
echo -e "   helm repo add eks https://aws.github.io/eks-charts && helm repo update"
echo -e "   helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=${CLUSTER_NAME} --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller"
echo -e ""
echo -e "${YELLOW}2. Test EBS CSI driver:${NC}"
echo -e "   kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-ebs-csi-driver/master/examples/kubernetes/dynamic-provisioning/specs/storageclass.yaml"
echo -e ""
echo -e "${YELLOW}3. Test ALB with sample app (after installing ALB controller):${NC}"
echo -e "   kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/examples/2048/2048_full.yaml"
echo -e ""
echo -e "${YELLOW}4. Cleanup when done:${NC}"
echo -e "   eksctl delete cluster --name $CLUSTER_NAME --region $REGION"
