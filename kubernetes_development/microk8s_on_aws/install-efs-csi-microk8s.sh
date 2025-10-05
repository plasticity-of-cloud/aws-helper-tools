#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script info
SCRIPT_NAME="EFS CSI Driver for MicroK8s Installer"
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

# Download EFS CSI driver IAM policy
echo -e "${YELLOW}Downloading EFS CSI driver IAM policy...${NC}"
curl -s -o /tmp/efs_csi_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-efs-csi-driver/master/docs/iam-policy-example.json

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

# Attach EFS CSI policy to existing role
echo -e "${YELLOW}Attaching EFS CSI policy to existing role...${NC}"
aws iam put-role-policy --role-name $EXISTING_ROLE --policy-name AmazonEFSCSIDriverPolicy --policy-document file:///tmp/efs_csi_policy.json

ROLE_NAME=$EXISTING_ROLE
PROFILE_NAME=$EXISTING_PROFILE

# Wait for IAM propagation
echo -e "${YELLOW}Waiting for IAM policy propagation...${NC}"
sleep 10

# Add AWS EFS CSI Helm repository
echo -e "${YELLOW}Adding AWS EFS CSI Helm repository...${NC}"
microk8s helm3 repo add aws-efs-csi-driver https://kubernetes-sigs.github.io/aws-efs-csi-driver
microk8s helm3 repo update

# Install EFS CSI Driver
echo -e "${YELLOW}Installing EFS CSI Driver...${NC}"
microk8s helm3 install aws-efs-csi-driver aws-efs-csi-driver/aws-efs-csi-driver --namespace kube-system

# Wait for deployment
echo -e "${YELLOW}Waiting for CSI driver to be ready...${NC}"
microk8s kubectl wait --for=condition=available --timeout=300s deployment/efs-csi-controller -n kube-system

# Create EFS StorageClass
echo -e "${YELLOW}Creating EFS StorageClass...${NC}"
microk8s kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: fs-example
  directoryPerms: "0755"
volumeBindingMode: Immediate
allowVolumeExpansion: false
EOF

# Verify installation
echo -e "${YELLOW}Verifying installation...${NC}"
microk8s kubectl get storageclass efs-sc
microk8s kubectl get pods -n kube-system -l app=efs-csi-controller

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${GREEN}EFS CSI Driver is now installed on your MicroK8s cluster.${NC}"
echo -e "${GREEN}IAM Role: ${ROLE_NAME}${NC}"
echo -e "${GREEN}Instance Profile: ${PROFILE_NAME}${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Create an EFS file system:"
echo "   aws efs create-file-system --region ${AWS_REGION} --tags Key=Name,Value=microk8s-efs"
echo ""
echo "2. Update the StorageClass with your EFS file system ID:"
echo "   kubectl patch storageclass efs-sc -p '{\"parameters\":{\"fileSystemId\":\"fs-YOUR-EFS-ID\"}}'"
echo ""
echo "3. Test with a PVC:"
echo "kubectl apply -f - <<EOF"
echo "apiVersion: v1"
echo "kind: PersistentVolumeClaim"
echo "metadata:"
echo "  name: test-efs-pvc"
echo "spec:"
echo "  accessModes:"
echo "  - ReadWriteMany"
echo "  storageClassName: efs-sc"
echo "  resources:"
echo "    requests:"
echo "      storage: 5Gi"
echo "EOF"
echo ""
echo -e "${GREEN}Benefits of EFS CSI over local storage:${NC}"
echo "• Shared storage across multiple pods"
echo "• ReadWriteMany access mode support"
echo "• Automatic scaling and high availability"
echo "• Cross-AZ access"
echo "• POSIX-compliant file system"
echo ""
echo -e "${GREEN}Happy file sharing! 📁${NC}"
