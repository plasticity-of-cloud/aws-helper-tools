#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script info
SCRIPT_NAME="EKS Pod Identity Agent for MicroK8s Installer"
VERSION="1.1.0"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}${SCRIPT_NAME}${NC}"
echo -e "${GREEN}Version: ${VERSION}${NC}"
echo -e "${GREEN}========================================${NC}"

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}Error: This script should not be run as root${NC}"
   exit 1
fi

# Check if MicroK8s is installed
if ! command -v microk8s &> /dev/null; then
    echo -e "${RED}Error: MicroK8s is not installed${NC}"
    exit 1
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is required but not installed${NC}"
    exit 1
fi

# Get AWS region and instance ID
echo -e "${YELLOW}Getting AWS metadata...${NC}"
AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo -e "${GREEN}AWS Region: ${AWS_REGION}${NC}"
echo -e "${GREEN}Instance ID: ${INSTANCE_ID}${NC}"
echo -e "${GREEN}Account ID: ${ACCOUNT_ID}${NC}"

# Enable required MicroK8s addons
echo -e "${YELLOW}Enabling MicroK8s addons...${NC}"
microk8s enable dns

# Wait for addons to be ready
echo -e "${YELLOW}Waiting for addons to be ready...${NC}"
microk8s status --wait-ready

# Create cluster name for Pod Identity
CLUSTER_NAME="microk8s-cluster"
echo -e "${GREEN}Using cluster name: ${CLUSTER_NAME}${NC}"

# Download the official EKS Pod Identity Agent manifest
echo -e "${YELLOW}Downloading EKS Pod Identity Agent manifest...${NC}"
curl -s -o /tmp/eks-pod-identity-agent.yaml https://raw.githubusercontent.com/aws/eks-pod-identity-agent/main/deploy/eks-pod-identity-agent.yaml

# Apply the Pod Identity Agent
echo -e "${YELLOW}Installing EKS Pod Identity Agent...${NC}"
microk8s kubectl apply -f /tmp/eks-pod-identity-agent.yaml

# Wait for Pod Identity Agent to be ready
echo -e "${YELLOW}Waiting for Pod Identity Agent to be ready...${NC}"
microk8s kubectl wait --for=condition=available --timeout=300s deployment/eks-pod-identity-agent -n kube-system

# Create Pod Identity Association role (basic permissions for testing)
echo -e "${YELLOW}Creating Pod Identity Association IAM role...${NC}"
ROLE_NAME="EKS-PodIdentity-Association-Role-$(date +%s)"

aws iam create-role --role-name $ROLE_NAME --assume-role-policy-document '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "pods.eks.amazonaws.com"
      },
      "Action": [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }
  ]
}' > /dev/null

# Attach basic S3 read policy for testing
echo -e "${YELLOW}Attaching test policy to Pod Identity role...${NC}"
aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

# Wait for IAM propagation
echo -e "${YELLOW}Waiting for IAM propagation...${NC}"
sleep 10

# Verify installation
echo -e "${YELLOW}Verifying installation...${NC}"
microk8s kubectl get pods -n kube-system -l app.kubernetes.io/name=eks-pod-identity-agent
microk8s kubectl get daemonset -n kube-system eks-pod-identity-agent

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${GREEN}EKS Pod Identity Agent is now installed on your MicroK8s cluster.${NC}"
echo -e "${GREEN}Test IAM Role: ${ROLE_NAME}${NC}"
echo -e "${GREEN}Cluster Name: ${CLUSTER_NAME}${NC}"
echo ""
echo -e "${YELLOW}Test Pod Identity with a service account:${NC}"
echo "# Create service account with Pod Identity annotation"
echo "kubectl create serviceaccount test-pod-identity -n default"
echo "kubectl annotate serviceaccount test-pod-identity -n default \\"
echo "  eks.amazonaws.com/role-arn=arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
echo ""
echo "# Test pod that uses the service account"
echo "kubectl apply -f - <<EOF"
echo "apiVersion: v1"
echo "kind: Pod"
echo "metadata:"
echo "  name: test-pod-identity"
echo "  namespace: default"
echo "spec:"
echo "  serviceAccountName: test-pod-identity"
echo "  containers:"
echo "  - name: aws-cli"
echo "    image: amazon/aws-cli:latest"
echo "    command: ['sleep', '3600']"
echo "EOF"
echo ""
echo "# Verify Pod Identity is working"
echo "kubectl exec test-pod-identity -- aws sts get-caller-identity"
echo "kubectl exec test-pod-identity -- aws s3 ls"
echo ""
echo -e "${GREEN}Benefits of EKS Pod Identity Agent:${NC}"
echo "• Pod-level IAM permissions (not node-level)"
echo "• Better security with least privilege"
echo "• No need to modify EC2 instance profiles"
echo "• Direct service account to IAM role mapping"
echo "• Easier credential management"
echo ""
echo -e "${GREEN}Ready for secure pod-level IAM! 🔐${NC}"
