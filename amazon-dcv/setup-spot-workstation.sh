#!/bin/bash

set -e

# Disable AWS CLI pager to prevent interactive prompts
export AWS_PAGER=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse command line arguments
ACCESS_CIDR="0.0.0.0/0"
REGION=""
ARCH=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --region)
            REGION="$2"
            shift 2
            ;;
        --access-cidr)
            ACCESS_CIDR="$2"
            shift 2
            ;;
        --arch)
            ARCH="$2"
            shift 2
            ;;
        *)
            echo "Unknown option $1"
            echo "Usage: $0 --region REGION [--access-cidr CIDR] [--arch x86|arm64]"
            exit 1
            ;;
    esac
done

if [ -z "$REGION" ]; then
    echo "Error: --region parameter is required"
    echo "Usage: $0 --region REGION [--access-cidr CIDR] [--arch x86|arm64]"
    exit 1
fi

# Validate architecture parameter
if [ -n "$ARCH" ] && [ "$ARCH" != "x86" ] && [ "$ARCH" != "arm64" ]; then
    echo "Error: --arch must be either 'x86' or 'arm64'"
    exit 1
fi

echo -e "${GREEN}=== EC2 Spot Instance with Hibernation Setup ===${NC}"
echo -e "${GREEN}Region: $REGION${NC}"

# Get Ubuntu 22.04 LTS AMI (hibernation supported)
echo -e "${YELLOW}Finding Ubuntu 22.04 LTS AMI (hibernation compatible)...${NC}"

# Set architecture - default to x86 if not specified
if [ -z "$ARCH" ]; then
    ARCH="x86"
    echo -e "${YELLOW}No architecture specified, defaulting to x86${NC}"
fi

# Map architecture to AMI architecture string
if [ "$ARCH" = "x86" ]; then
    AMI_ARCH="amd64"
    DEFAULT_INSTANCE_TYPE="m7i.2xlarge"
else
    AMI_ARCH="arm64"
    DEFAULT_INSTANCE_TYPE="m7g.2xlarge"
fi

echo -e "${GREEN}Using architecture: $ARCH ($AMI_ARCH)${NC}"

AMI_ID=$(aws ec2 describe-images \
    --region $REGION \
    --owners 099720109477 \
    --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-${AMI_ARCH}-server-*" \
              "Name=state,Values=available" \
    --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
    --output text)

if [ "$AMI_ID" = "None" ] || [ -z "$AMI_ID" ]; then
    echo -e "${RED}Ubuntu 22.04 LTS AMI not found for $AMI_ARCH architecture${NC}"
    exit 1
fi
echo -e "${GREEN}Found AMI: $AMI_ID ($AMI_ARCH)${NC}"

# Get default VPC
VPC_ID=$(aws ec2 describe-vpcs \
    --region $REGION \
    --filters "Name=is-default,Values=true" \
    --query 'Vpcs[0].VpcId' \
    --output text)

if [ "$VPC_ID" = "None" ]; then
    echo -e "${RED}Default VPC not found${NC}"
    exit 1
fi

# Get VPC CIDR
VPC_CIDR=$(aws ec2 describe-vpcs \
    --region $REGION \
    --vpc-ids $VPC_ID \
    --query 'Vpcs[0].CidrBlock' \
    --output text)

echo -e "${GREEN}Using VPC: $VPC_ID ($VPC_CIDR)${NC}"

# Allocate Elastic IP
echo -e "${YELLOW}Allocating Elastic IP...${NC}"
EIP_ALLOC=$(aws ec2 allocate-address \
    --region $REGION \
    --domain vpc \
    --query 'AllocationId' \
    --output text)

EIP_ADDRESS=$(aws ec2 describe-addresses \
    --region $REGION \
    --allocation-ids $EIP_ALLOC \
    --query 'Addresses[0].PublicIp' \
    --output text)

echo -e "${GREEN}Allocated Elastic IP: $EIP_ADDRESS ($EIP_ALLOC)${NC}"

# Create security group
SG_NAME="hibernation-spot-sg-$(date +%s)"
echo -e "${YELLOW}Creating security group...${NC}"

SG_ID=$(aws ec2 create-security-group \
    --region $REGION \
    --group-name $SG_NAME \
    --description "Security group for hibernation spot instance with DCV" \
    --vpc-id $VPC_ID \
    --query 'GroupId' \
    --output text)

# Add security group rules with configurable CIDR
aws ec2 authorize-security-group-ingress \
    --region $REGION \
    --group-id $SG_ID \
    --protocol tcp \
    --port 22 \
    --cidr $ACCESS_CIDR

aws ec2 authorize-security-group-ingress \
    --region $REGION \
    --group-id $SG_ID \
    --protocol tcp \
    --port 8443 \
    --cidr $ACCESS_CIDR

echo -e "${GREEN}Security group created: $SG_ID${NC}"

# Create S3 bucket for scripts first (needed for IAM policy)
BUCKET_NAME="dcv-workstation-scripts-$(date +%s)-$(openssl rand -hex 4)"
echo -e "${YELLOW}Creating S3 bucket for scripts...${NC}"

aws s3 mb s3://$BUCKET_NAME --region $REGION

# Upload scripts to S3
aws s3 cp "$(dirname "$0")/install-dcv-ubuntu.sh" s3://$BUCKET_NAME/install-dcv-ubuntu.sh
aws s3 cp "$(dirname "$0")/dcv-install-config.sh" s3://$BUCKET_NAME/dcv-install-config.sh

echo -e "${GREEN}Scripts uploaded to S3 bucket: $BUCKET_NAME${NC}"

# Create IAM role for SSM with unique names
TIMESTAMP=$(date +%s)
ROLE_NAME="DCV-Workstation-SSM-Role-$TIMESTAMP"
POLICY_NAME="DCV-License-S3-Access-$TIMESTAMP"
echo -e "${YELLOW}Creating IAM role: $ROLE_NAME${NC}"

cat > /tmp/trust-policy.json << EOF
{
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
}
EOF

aws iam create-role \
    --role-name $ROLE_NAME \
    --assume-role-policy-document file:///tmp/trust-policy.json \
    --no-cli-pager

aws iam attach-role-policy \
    --role-name $ROLE_NAME \
    --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore \
    --no-cli-pager

# Create and attach DCV license S3 access policy with correct permissions
cat > /tmp/dcv-license-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::dcv-license.$REGION/*"
        },
        {
            "Effect": "Allow",
            "Action": ["s3:GetObject", "s3:ListBucket"],
            "Resource": [
                "arn:aws:s3:::$BUCKET_NAME",
                "arn:aws:s3:::$BUCKET_NAME/*"
            ]
        }
    ]
}
EOF

echo -e "${YELLOW}Creating IAM policy: $POLICY_NAME${NC}"
POLICY_ARN=$(aws iam create-policy \
    --policy-name $POLICY_NAME \
    --policy-document file:///tmp/dcv-license-policy.json \
    --query 'Policy.Arn' --output text \
    --no-cli-pager)

aws iam attach-role-policy \
    --role-name $ROLE_NAME \
    --policy-arn $POLICY_ARN \
    --no-cli-pager

aws iam create-instance-profile \
    --instance-profile-name $ROLE_NAME \
    --no-cli-pager

aws iam add-role-to-instance-profile \
    --instance-profile-name $ROLE_NAME \
    --role-name $ROLE_NAME \
    --no-cli-pager

echo -e "${GREEN}IAM role created: $ROLE_NAME${NC}"
sleep 30

# Create user data script that downloads and executes DCV scripts from S3
USER_DATA=$(cat << EOF
#!/bin/bash
apt-get update
apt-get install -y snapd

# Install AWS CLI and SSM agent via snap
snap install aws-cli --classic
snap install amazon-ssm-agent --classic

systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service

# Disable KASLR for Ubuntu hibernation (AWS recommendation)
echo "Disabling KASLR for hibernation compatibility..."
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& nokaslr/' /etc/default/grub
update-grub

sleep 30

REGION=\$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

aws s3 cp s3://$BUCKET_NAME/dcv-install-config.sh /tmp/dcv-install-config.sh
aws s3 cp s3://$BUCKET_NAME/install-dcv-ubuntu.sh /tmp/install-dcv-ubuntu.sh

chmod +x /tmp/dcv-install-config.sh /tmp/install-dcv-ubuntu.sh

cd /tmp
source ./dcv-install-config.sh
sudo -u ubuntu ./install-dcv-ubuntu.sh

echo "Setup complete"
EOF
)

# Encode user data
USER_DATA_B64=$(echo "$USER_DATA" | base64 -w 0)

# Create launch template
TEMPLATE_NAME="hibernation-spot-template-$(date +%s)"
echo -e "${YELLOW}Creating launch template...${NC}"

aws ec2 create-launch-template \
    --region $REGION \
    --launch-template-name $TEMPLATE_NAME \
    --launch-template-data "{
        \"ImageId\": \"$AMI_ID\",
        \"InstanceType\": \"$DEFAULT_INSTANCE_TYPE\",
        \"SecurityGroupIds\": [\"$SG_ID\"],
        \"IamInstanceProfile\": {
            \"Name\": \"$ROLE_NAME\"
        },
        \"BlockDeviceMappings\": [{
            \"DeviceName\": \"/dev/sda1\",
            \"Ebs\": {
                \"VolumeSize\": 100,
                \"VolumeType\": \"gp3\",
                \"Throughput\": 500,
                \"Encrypted\": true,
                \"DeleteOnTermination\": true
            }
        }],
        \"UserData\": \"$USER_DATA_B64\",
        \"HibernationOptions\": {
            \"Configured\": true
        }
    }" > /dev/null

echo -e "${GREEN}Launch template created: $TEMPLATE_NAME${NC}"

# Launch spot instance
echo -e "${YELLOW}Launching spot instance...${NC}"

INSTANCE_ID=$(aws ec2 run-instances \
    --region $REGION \
    --launch-template "LaunchTemplateName=$TEMPLATE_NAME" \
    --instance-market-options '{
        "MarketType": "spot",
        "SpotOptions": {
            "SpotInstanceType": "persistent",
            "InstanceInterruptionBehavior": "hibernate"
        }
    }' \
    --query 'Instances[0].InstanceId' \
    --output text)

echo -e "${GREEN}Instance launched: $INSTANCE_ID${NC}"

# Wait for instance to be running
echo -e "${YELLOW}Waiting for instance to be running...${NC}"
aws ec2 wait instance-running --region $REGION --instance-ids $INSTANCE_ID

# Associate Elastic IP
echo -e "${YELLOW}Associating Elastic IP...${NC}"
aws ec2 associate-address \
    --region $REGION \
    --instance-id $INSTANCE_ID \
    --allocation-id $EIP_ALLOC > /dev/null

# Get instance details
INSTANCE_IP=$(aws ec2 describe-instances \
    --region $REGION \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text)

echo -e "${GREEN}=== Setup Complete ===${NC}"
echo -e "${GREEN}Instance ID: $INSTANCE_ID${NC}"
echo -e "${GREEN}Architecture: $ARCH ($DEFAULT_INSTANCE_TYPE)${NC}"
echo -e "${GREEN}Public IP (Static): $EIP_ADDRESS${NC}"
echo -e "${GREEN}Private IP: $INSTANCE_IP${NC}"
echo -e "${GREEN}SSH Access: ssh ubuntu@$EIP_ADDRESS${NC}"
echo -e "${GREEN}DCV Access: https://$EIP_ADDRESS:8443${NC}"
echo -e "${YELLOW}Note: Wait ~10 minutes for DCV setup to complete${NC}"
echo -e ""
echo -e "${YELLOW}📋 Next Steps:${NC}"
echo -e "${YELLOW}1. Set password for ubuntu user:${NC}"
echo -e "   aws ssm send-command --region $REGION --instance-ids $INSTANCE_ID --document-name 'AWS-RunShellScript' --parameters 'commands=[\"echo ubuntu:YOUR_PASSWORD | sudo chpasswd\"]'"
echo -e ""
echo -e "${YELLOW}2. Access your workstation:${NC}"
echo -e "   • Open: https://$EIP_ADDRESS:8443"
echo -e "   • Username: ubuntu"
echo -e "   • Password: (the one you set above)"

# Create cleanup script in organized directory
mkdir -p $HOME/spot-workstations
cat > $HOME/spot-workstations/cleanup-$INSTANCE_ID.sh << EOL
#!/bin/bash
echo "Cleaning up resources..."
aws ec2 terminate-instances --region $REGION --instance-ids $INSTANCE_ID --force
echo "Waiting for instance to terminate..."
aws ec2 wait instance-terminated --region $REGION --instance-ids $INSTANCE_ID
aws ec2 release-address --region $REGION --allocation-id $EIP_ALLOC
aws ec2 delete-launch-template --region $REGION --launch-template-name $TEMPLATE_NAME
aws ec2 delete-security-group --region $REGION --group-id $SG_ID
aws s3 rm s3://$BUCKET_NAME --recursive
aws s3 rb s3://$BUCKET_NAME
# Clean up IAM resources
aws iam detach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
aws iam detach-role-policy --role-name $ROLE_NAME --policy-arn $POLICY_ARN
aws iam remove-role-from-instance-profile --instance-profile-name $ROLE_NAME --role-name $ROLE_NAME
aws iam delete-instance-profile --instance-profile-name $ROLE_NAME
aws iam delete-role --role-name $ROLE_NAME
aws iam delete-policy --policy-arn $POLICY_ARN
echo "Cleanup complete"
EOL

chmod +x $HOME/spot-workstations/cleanup-$INSTANCE_ID.sh
echo -e "${YELLOW}Cleanup script created: $HOME/spot-workstations/cleanup-$INSTANCE_ID.sh${NC}"
