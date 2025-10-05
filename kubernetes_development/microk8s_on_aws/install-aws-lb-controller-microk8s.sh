#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script info
SCRIPT_NAME="AWS Load Balancer Controller for MicroK8s Installer"
VERSION="2.0.0"

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

# Get AWS region, instance ID, and VPC ID
echo -e "${YELLOW}Getting AWS metadata...${NC}"
AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
VPC_ID=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $AWS_REGION --query 'Reservations[0].Instances[0].VpcId' --output text)

echo -e "${GREEN}AWS Region: ${AWS_REGION}${NC}"
echo -e "${GREEN}Instance ID: ${INSTANCE_ID}${NC}"
echo -e "${GREEN}VPC ID: ${VPC_ID}${NC}"

# Enable required MicroK8s addons
echo -e "${YELLOW}Enabling MicroK8s addons...${NC}"
microk8s enable dns helm3

# Wait for addons to be ready
echo -e "${YELLOW}Waiting for addons to be ready...${NC}"
microk8s status --wait-ready

# Download AWS Load Balancer Controller IAM policy
echo -e "${YELLOW}Downloading AWS Load Balancer Controller IAM policy...${NC}"
curl -s -o /tmp/alb_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json

# Get current instance role
echo -e "${YELLOW}Getting current instance IAM role...${NC}"
CURRENT_ASSOCIATION=$(aws ec2 describe-iam-instance-profile-associations --filters Name=instance-id,Values=$INSTANCE_ID --region $AWS_REGION --query 'IamInstanceProfileAssociations[0].IamInstanceProfile.Arn' --output text 2>/dev/null || echo "None")

if [ "$CURRENT_ASSOCIATION" == "None" ] || [ "$CURRENT_ASSOCIATION" == "" ]; then
    echo -e "${RED}Error: No IAM instance profile found. Please attach an IAM role to this instance first.${NC}"
    exit 1
fi

# Extract role name from existing instance profile
EXISTING_PROFILE=$(basename $CURRENT_ASSOCIATION)
EXISTING_ROLE=$(aws iam get-instance-profile --instance-profile-name $EXISTING_PROFILE --query 'InstanceProfile.Roles[0].RoleName' --output text 2>/dev/null || echo "None")

if [ "$EXISTING_ROLE" == "None" ]; then
    echo -e "${RED}Error: No IAM role found in instance profile. Please ensure the instance has a valid IAM role.${NC}"
    exit 1
fi

echo -e "${GREEN}Found existing IAM role: ${EXISTING_ROLE}${NC}"

# Attach Load Balancer Controller policy to existing role
echo -e "${YELLOW}Attaching Load Balancer Controller policy to existing role...${NC}"
aws iam put-role-policy --role-name $EXISTING_ROLE --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file:///tmp/alb_policy.json

ROLE_NAME=$EXISTING_ROLE
PROFILE_NAME=$EXISTING_PROFILE

# Wait for IAM propagation
echo -e "${YELLOW}Waiting for IAM policy propagation...${NC}"
sleep 10
    echo -e "${YELLOW}Creating instance profile...${NC}"
    aws iam create-instance-profile --instance-profile-name $PROFILE_NAME > /dev/null
    aws iam add-role-to-instance-profile --instance-profile-name $PROFILE_NAME --role-name $ROLE_NAME

    # Wait for IAM propagation
    echo -e "${YELLOW}Waiting for IAM propagation...${NC}"
    sleep 10

    # Replace instance profile
    echo -e "${YELLOW}Replacing instance profile...${NC}"
    CURRENT_ASSOCIATION_ID=$(aws ec2 describe-iam-instance-profile-associations --filters Name=instance-id,Values=$INSTANCE_ID --region $AWS_REGION --query 'IamInstanceProfileAssociations[0].AssociationId' --output text)

    if [ "$CURRENT_ASSOCIATION_ID" != "None" ] && [ "$CURRENT_ASSOCIATION_ID" != "" ]; then
        aws ec2 replace-iam-instance-profile-association --iam-instance-profile Name=$PROFILE_NAME --association-id $CURRENT_ASSOCIATION_ID --region $AWS_REGION > /dev/null
    else
        aws ec2 associate-iam-instance-profile --instance-id $INSTANCE_ID --iam-instance-profile Name=$PROFILE_NAME --region $AWS_REGION > /dev/null
    fi

    # Wait for association
    echo -e "${YELLOW}Waiting for IAM association...${NC}"
    sleep 15
fi

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
echo -e "${GREEN}IAM Role: ${ROLE_NAME}${NC}"
echo -e "${GREEN}Instance Profile: ${PROFILE_NAME}${NC}"
echo ""
echo -e "${YELLOW}Test with a LoadBalancer service:${NC}"
echo "kubectl apply -f - <<EOF"
echo "apiVersion: v1"
echo "kind: Service"
echo "metadata:"
echo "  name: test-nlb-service"
echo "  annotations:"
echo "    service.beta.kubernetes.io/aws-load-balancer-type: nlb"
echo "    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing"
echo "spec:"
echo "  type: LoadBalancer"
echo "  ports:"
echo "  - port: 80"
echo "    targetPort: 8080"
echo "  selector:"
echo "    app: test-app"
echo "EOF"
echo ""
echo -e "${GREEN}Benefits of AWS Load Balancer Controller:${NC}"
echo "• Application Load Balancer (ALB) support"
echo "• Network Load Balancer (NLB) support"
echo "• Advanced routing and SSL termination"
echo "• Integration with AWS Certificate Manager"
echo "• Cost-effective load balancing"
echo ""
echo -e "${GREEN}Happy load balancing! ⚖️${NC}"
