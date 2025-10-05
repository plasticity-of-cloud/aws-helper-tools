#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script info
SCRIPT_NAME="AWS Load Balancer Controller for MicroK8s Installer"
VERSION="1.0.0"

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

# Check if Helm is installed
if ! command -v helm &> /dev/null; then
    echo -e "${YELLOW}Installing Helm...${NC}"
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Get AWS region and VPC ID
echo -e "${YELLOW}Getting AWS metadata...${NC}"
AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

# Get VPC ID using AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is required but not installed${NC}"
    exit 1
fi

VPC_ID=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $AWS_REGION --query 'Reservations[0].Instances[0].VpcId' --output text)

echo -e "${GREEN}AWS Region: ${AWS_REGION}${NC}"
echo -e "${GREEN}VPC ID: ${VPC_ID}${NC}"

# Enable required MicroK8s addons
echo -e "${YELLOW}Enabling MicroK8s addons...${NC}"
microk8s enable dns storage helm3

# Wait for addons to be ready
echo -e "${YELLOW}Waiting for addons to be ready...${NC}"
microk8s status --wait-ready

# Configure kubectl
echo -e "${YELLOW}Configuring kubectl...${NC}"
mkdir -p ~/.kube
microk8s kubectl config view --raw > ~/.kube/config

# Download IAM policy
echo -e "${YELLOW}Downloading AWS Load Balancer Controller IAM policy...${NC}"
curl -s -o /tmp/iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json

echo -e "${YELLOW}IAM policy downloaded to /tmp/iam_policy.json${NC}"
echo -e "${YELLOW}Please ensure your EC2 instance has the required IAM permissions.${NC}"

# Add EKS Helm repository
echo -e "${YELLOW}Adding EKS Helm repository...${NC}"
microk8s helm3 repo add eks https://aws.github.io/eks-charts
microk8s helm3 repo update

# Install AWS Load Balancer Controller
echo -e "${YELLOW}Installing AWS Load Balancer Controller...${NC}"
microk8s helm3 install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=microk8s-cluster \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=$AWS_REGION \
  --set vpcId=$VPC_ID

# Wait for deployment
echo -e "${YELLOW}Waiting for controller to be ready...${NC}"
microk8s kubectl wait --for=condition=available --timeout=300s deployment/aws-load-balancer-controller -n kube-system

# Verify installation
echo -e "${YELLOW}Verifying installation...${NC}"
microk8s kubectl get deployment -n kube-system aws-load-balancer-controller

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${GREEN}AWS Load Balancer Controller is now installed on your MicroK8s cluster.${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Ensure your EC2 instance has the IAM policy attached:"
echo "   aws iam put-role-policy --role-name <your-ec2-role> --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file:///tmp/iam_policy.json"
echo ""
echo "2. Create a LoadBalancer service or Ingress to test:"
echo "   kubectl apply -f - <<EOF"
echo "   apiVersion: v1"
echo "   kind: Service"
echo "   metadata:"
echo "     name: test-service"
echo "     annotations:"
echo "       service.beta.kubernetes.io/aws-load-balancer-type: nlb"
echo "   spec:"
echo "     type: LoadBalancer"
echo "     ports:"
echo "     - port: 80"
echo "       targetPort: 8080"
echo "     selector:"
echo "       app: test-app"
echo "   EOF"
echo ""
echo -e "${GREEN}Happy Kubernetes-ing! 🚀${NC}"
