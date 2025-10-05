#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script info
SCRIPT_NAME="Mountpoint for S3 CSI Driver for MicroK8s Installer"
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

# Create S3 CSI driver IAM policy
echo -e "${YELLOW}Creating S3 CSI driver IAM policy...${NC}"
cat > /tmp/s3_csi_policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:GetObjectVersion",
        "s3:DeleteObjectVersion"
      ],
      "Resource": [
        "arn:aws:s3:::*",
        "arn:aws:s3:::*/*"
      ]
    }
  ]
}
EOF

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

# Attach S3 CSI policy to existing role
echo -e "${YELLOW}Attaching S3 CSI policy to existing role...${NC}"
aws iam put-role-policy --role-name $EXISTING_ROLE --policy-name AmazonS3CSIDriverPolicy --policy-document file:///tmp/s3_csi_policy.json

ROLE_NAME=$EXISTING_ROLE
PROFILE_NAME=$EXISTING_PROFILE

# Wait for IAM propagation
echo -e "${YELLOW}Waiting for IAM policy propagation...${NC}"
sleep 10
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

# Add AWS Mountpoint S3 CSI Helm repository
echo -e "${YELLOW}Adding AWS Mountpoint S3 CSI Helm repository...${NC}"
microk8s helm3 repo add aws-mountpoint-s3-csi-driver https://awslabs.github.io/mountpoint-s3-csi-driver
microk8s helm3 repo update

# Install Mountpoint S3 CSI Driver
echo -e "${YELLOW}Installing Mountpoint S3 CSI Driver...${NC}"
microk8s helm3 install aws-mountpoint-s3-csi-driver aws-mountpoint-s3-csi-driver/aws-mountpoint-s3-csi-driver --namespace kube-system

# Wait for deployment
echo -e "${YELLOW}Waiting for CSI driver to be ready...${NC}"
microk8s kubectl wait --for=condition=available --timeout=300s deployment/s3-csi-driver-controller -n kube-system

# Create S3 StorageClass
echo -e "${YELLOW}Creating S3 StorageClass...${NC}"
microk8s kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: s3-csi
provisioner: s3.csi.aws.com
parameters:
  bucketName: example-bucket
  region: ${AWS_REGION}
volumeBindingMode: Immediate
allowVolumeExpansion: false
EOF

# Verify installation
echo -e "${YELLOW}Verifying installation...${NC}"
microk8s kubectl get storageclass s3-csi
microk8s kubectl get pods -n kube-system -l app=s3-csi-driver

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${GREEN}Mountpoint for S3 CSI Driver is now installed on your MicroK8s cluster.${NC}"
echo -e "${GREEN}IAM Role: ${ROLE_NAME}${NC}"
echo -e "${GREEN}Instance Profile: ${PROFILE_NAME}${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Create an S3 bucket:"
echo "   aws s3 mb s3://my-microk8s-bucket --region ${AWS_REGION}"
echo ""
echo "2. Update the StorageClass with your S3 bucket name:"
echo "   kubectl patch storageclass s3-csi -p '{\"parameters\":{\"bucketName\":\"my-microk8s-bucket\"}}'"
echo ""
echo "3. Test with a PV (S3 requires static provisioning):"
echo "kubectl apply -f - <<EOF"
echo "apiVersion: v1"
echo "kind: PersistentVolume"
echo "metadata:"
echo "  name: test-s3-pv"
echo "spec:"
echo "  capacity:"
echo "    storage: 1200Gi"
echo "  accessModes:"
echo "  - ReadWriteMany"
echo "  mountOptions:"
echo "  - allow-delete"
echo "  - region ${AWS_REGION}"
echo "  csi:"
echo "    driver: s3.csi.aws.com"
echo "    volumeHandle: my-microk8s-bucket"
echo "    volumeAttributes:"
echo "      bucketName: my-microk8s-bucket"
echo "---"
echo "apiVersion: v1"
echo "kind: PersistentVolumeClaim"
echo "metadata:"
echo "  name: test-s3-pvc"
echo "spec:"
echo "  accessModes:"
echo "  - ReadWriteMany"
echo "  storageClassName: \"\""
echo "  resources:"
echo "    requests:"
echo "      storage: 1200Gi"
echo "  volumeName: test-s3-pv"
echo "EOF"
echo ""
echo -e "${GREEN}Benefits of S3 CSI over local storage:${NC}"
echo "• Virtually unlimited storage capacity"
echo "• High durability (99.999999999%)"
echo "• Cost-effective for large datasets"
echo "• Global accessibility"
echo "• Integration with S3 lifecycle policies"
echo ""
echo -e "${GREEN}Happy object storing! 🪣${NC}"
