#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script info
SCRIPT_NAME="Amazon CloudWatch Observability for MicroK8s Installer"
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

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is required but not installed${NC}"
    exit 1
fi

# Get AWS region and instance ID
echo -e "${YELLOW}Getting AWS metadata...${NC}"
AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

echo -e "${GREEN}AWS Region: ${AWS_REGION}${NC}"
echo -e "${GREEN}Instance ID: ${INSTANCE_ID}${NC}"

# Enable required MicroK8s addons
echo -e "${YELLOW}Enabling MicroK8s addons...${NC}"
microk8s enable dns helm3

# Wait for addons to be ready
echo -e "${YELLOW}Waiting for addons to be ready...${NC}"
microk8s status --wait-ready

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

# Attach CloudWatch Agent Server policy to existing role
echo -e "${YELLOW}Attaching CloudWatch Agent Server policy to existing role...${NC}"
aws iam attach-role-policy --role-name $EXISTING_ROLE --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy

ROLE_NAME=$EXISTING_ROLE
PROFILE_NAME=$EXISTING_PROFILE

# Wait for IAM propagation
echo -e "${YELLOW}Waiting for IAM policy propagation...${NC}"
sleep 10

# Add AWS Observability Helm repository
echo -e "${YELLOW}Adding AWS Observability Helm repository...${NC}"
microk8s helm3 repo add aws-observability https://aws-observability.github.io/helm-charts
microk8s helm3 repo update

# Install Amazon CloudWatch Observability
echo -e "${YELLOW}Installing Amazon CloudWatch Observability...${NC}"
microk8s helm3 install --wait --create-namespace --namespace amazon-cloudwatch \
  amazon-cloudwatch aws-observability/amazon-cloudwatch-observability \
  --set clusterName=microk8s-cluster \
  --set region=$AWS_REGION \
  --set k8sMode=K8S

# Wait for deployment
echo -e "${YELLOW}Waiting for CloudWatch Observability to be ready...${NC}"
microk8s kubectl wait --for=condition=available --timeout=300s deployment/amazon-cloudwatch-amazon-cloudwatch-observability -n amazon-cloudwatch

# Verify installation
echo -e "${YELLOW}Verifying installation...${NC}"
microk8s kubectl get pods -n amazon-cloudwatch
microk8s kubectl get daemonset -n amazon-cloudwatch

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${GREEN}Amazon CloudWatch Observability is now installed on your MicroK8s cluster.${NC}"
echo -e "${GREEN}IAM Role: ${ROLE_NAME}${NC}"
echo -e "${GREEN}Instance Profile: ${PROFILE_NAME}${NC}"
echo ""
echo -e "${YELLOW}Components installed:${NC}"
echo "• CloudWatch Agent Operator - Manages CloudWatch agents"
echo "• Fluent Bit DaemonSet - Collects container logs"
echo "• Container Insights - Infrastructure metrics"
echo "• Application Signals - Application performance telemetry"
echo ""
echo -e "${YELLOW}View your data in AWS Console:${NC}"
echo "1. CloudWatch Container Insights:"
echo "   https://${AWS_REGION}.console.aws.amazon.com/cloudwatch/home?region=${AWS_REGION}#container-insights:infrastructure"
echo ""
echo "2. CloudWatch Application Signals:"
echo "   https://${AWS_REGION}.console.aws.amazon.com/cloudwatch/home?region=${AWS_REGION}#application-signals:services"
echo ""
echo "3. CloudWatch Logs:"
echo "   https://${AWS_REGION}.console.aws.amazon.com/cloudwatch/home?region=${AWS_REGION}#logsV2:log-groups"
echo ""
echo -e "${YELLOW}Test Application Signals with a sample app:${NC}"
echo "kubectl apply -f - <<EOF"
echo "apiVersion: apps/v1"
echo "kind: Deployment"
echo "metadata:"
echo "  name: sample-app"
echo "  namespace: default"
echo "  annotations:"
echo "    instrumentation.opentelemetry.io/inject-java: \"amazon-cloudwatch/amazon-cloudwatch-observability\""
echo "spec:"
echo "  replicas: 1"
echo "  selector:"
echo "    matchLabels:"
echo "      app: sample-app"
echo "  template:"
echo "    metadata:"
echo "      labels:"
echo "        app: sample-app"
echo "    spec:"
echo "      containers:"
echo "      - name: app"
echo "        image: public.ecr.aws/docker/library/openjdk:11-jre"
echo "        command: ['sleep', '3600']"
echo "EOF"
echo ""
echo -e "${GREEN}Benefits of CloudWatch Observability:${NC}"
echo "• Complete observability stack in one installation"
echo "• Container Insights for infrastructure monitoring"
echo "• Application Signals for APM and distributed tracing"
echo "• Centralized logging with Fluent Bit"
echo "• Auto-instrumentation for Java, Python, .NET, Node.js"
echo "• Integration with CloudWatch dashboards and alarms"
echo ""
echo -e "${GREEN}Happy observing! 📊${NC}"
