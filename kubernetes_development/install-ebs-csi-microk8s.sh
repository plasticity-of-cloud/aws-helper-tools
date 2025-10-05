#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script info
SCRIPT_NAME="EBS CSI Driver for MicroK8s Installer"
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

# Download EBS CSI driver IAM policy
echo -e "${YELLOW}Downloading EBS CSI driver IAM policy...${NC}"
curl -s -o /tmp/ebs_csi_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-ebs-csi-driver/master/docs/example-iam-policy.json

# Create IAM role for EBS CSI
echo -e "${YELLOW}Creating IAM role for EBS CSI...${NC}"
ROLE_NAME="EBS-CSI-MicroK8s-Role-$(date +%s)"
PROFILE_NAME="EBS-CSI-MicroK8s-Profile-$(date +%s)"

aws iam create-role --role-name $ROLE_NAME --assume-role-policy-document '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}' > /dev/null

# Attach EBS CSI policy to role
echo -e "${YELLOW}Attaching EBS CSI policy to role...${NC}"
aws iam put-role-policy --role-name $ROLE_NAME --policy-name AmazonEBSCSIDriverPolicy --policy-document file:///tmp/ebs_csi_policy.json

# Create instance profile
echo -e "${YELLOW}Creating instance profile...${NC}"
aws iam create-instance-profile --instance-profile-name $PROFILE_NAME > /dev/null
aws iam add-role-to-instance-profile --instance-profile-name $PROFILE_NAME --role-name $ROLE_NAME

# Wait for IAM propagation
echo -e "${YELLOW}Waiting for IAM propagation...${NC}"
sleep 10

# Get current instance profile association
echo -e "${YELLOW}Replacing instance profile...${NC}"
CURRENT_ASSOCIATION=$(aws ec2 describe-iam-instance-profile-associations --filters Name=instance-id,Values=$INSTANCE_ID --region $AWS_REGION --query 'IamInstanceProfileAssociations[0].AssociationId' --output text)

if [ "$CURRENT_ASSOCIATION" != "None" ] && [ "$CURRENT_ASSOCIATION" != "" ]; then
    # Replace existing association
    aws ec2 replace-iam-instance-profile-association --iam-instance-profile Name=$PROFILE_NAME --association-id $CURRENT_ASSOCIATION --region $AWS_REGION > /dev/null
else
    # Associate new profile
    aws ec2 associate-iam-instance-profile --instance-id $INSTANCE_ID --iam-instance-profile Name=$PROFILE_NAME --region $AWS_REGION > /dev/null
fi

# Wait for association
echo -e "${YELLOW}Waiting for IAM association...${NC}"
sleep 15

# Add AWS EBS CSI Helm repository
echo -e "${YELLOW}Adding AWS EBS CSI Helm repository...${NC}"
microk8s helm3 repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
microk8s helm3 repo update

# Install EBS CSI Driver
echo -e "${YELLOW}Installing EBS CSI Driver...${NC}"
microk8s helm3 install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver --namespace kube-system

# Wait for deployment
echo -e "${YELLOW}Waiting for CSI driver to be ready...${NC}"
microk8s kubectl wait --for=condition=available --timeout=300s deployment/ebs-csi-controller -n kube-system

# Create gp3 StorageClass (recommended for better performance)
echo -e "${YELLOW}Creating gp3 StorageClass...${NC}"
microk8s kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-gp3
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
  encrypted: "true"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF

# Remove default MicroK8s storage class
echo -e "${YELLOW}Updating default storage class...${NC}"
microk8s kubectl patch storageclass microk8s-hostpath -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}' 2>/dev/null || true

# Verify installation
echo -e "${YELLOW}Verifying installation...${NC}"
microk8s kubectl get storageclass
microk8s kubectl get pods -n kube-system -l app=ebs-csi-controller

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${GREEN}EBS CSI Driver is now installed on your MicroK8s cluster.${NC}"
echo -e "${GREEN}IAM Role: ${ROLE_NAME}${NC}"
echo -e "${GREEN}Instance Profile: ${PROFILE_NAME}${NC}"
echo ""
echo -e "${YELLOW}Test with a PVC:${NC}"
echo "kubectl apply -f - <<EOF"
echo "apiVersion: v1"
echo "kind: PersistentVolumeClaim"
echo "metadata:"
echo "  name: test-ebs-pvc"
echo "spec:"
echo "  accessModes:"
echo "  - ReadWriteOnce"
echo "  storageClassName: ebs-gp3"
echo "  resources:"
echo "    requests:"
echo "      storage: 10Gi"
echo "EOF"
echo ""
echo -e "${GREEN}Benefits of EBS CSI over MicroK8s hostpath:${NC}"
echo "• Persistent storage survives pod restarts"
echo "• Volume snapshots and backups"
echo "• Dynamic volume resizing"
echo "• Better performance with gp3 volumes"
echo "• Encryption at rest"
echo ""
echo -e "${GREEN}Happy storing! 💾${NC}"
