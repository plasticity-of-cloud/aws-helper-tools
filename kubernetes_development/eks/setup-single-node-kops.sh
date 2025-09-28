#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Parse command line arguments
REGION=""
CLUSTER_NAME=""
DOMAIN_NAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --region)
            REGION="$2"
            shift 2
            ;;
        --cluster-name)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        --domain-name)
            DOMAIN_NAME="$2"
            shift 2
            ;;
        *)
            echo "Unknown option $1"
            echo "Usage: $0 --region REGION --cluster-name CLUSTER_NAME [--domain-name DOMAIN_NAME]"
            exit 1
            ;;
    esac
done

if [ -z "$REGION" ] || [ -z "$CLUSTER_NAME" ]; then
    echo "Error: --region and --cluster-name parameters are required"
    echo "Usage: $0 --region REGION --cluster-name CLUSTER_NAME [--domain-name DOMAIN_NAME]"
    exit 1
fi

echo -e "${GREEN}=== Setting up single-node kops cluster ===${NC}"
echo -e "${GREEN}Region: $REGION${NC}"
echo -e "${GREEN}Cluster Name: $CLUSTER_NAME${NC}"

# Create S3 bucket for kops state
BUCKET_NAME="kops-state-${CLUSTER_NAME}-$(date +%s)"
echo -e "${YELLOW}Creating S3 bucket for kops state...${NC}"
aws s3 mb s3://$BUCKET_NAME --region $REGION

# Enable bucket versioning
aws s3api put-bucket-versioning \
    --bucket $BUCKET_NAME \
    --versioning-configuration Status=Enabled

# Set environment variables
export KOPS_STATE_STORE=s3://$BUCKET_NAME
export KOPS_FEATURE_FLAGS=AlphaAllowGCE

# Create cluster configuration
if [ -n "$DOMAIN_NAME" ]; then
    FULL_CLUSTER_NAME="${CLUSTER_NAME}.${DOMAIN_NAME}"
else
    FULL_CLUSTER_NAME="${CLUSTER_NAME}.k8s.local"
fi

echo -e "${YELLOW}Creating cluster configuration...${NC}"
kops create cluster \
    --name=$FULL_CLUSTER_NAME \
    --cloud=aws \
    --zones=${REGION}a \
    --master-size=t3.medium \
    --node-size=t3.medium \
    --node-count=0 \
    --master-count=1 \
    --networking=calico \
    --topology=private \
    --api-loadbalancer-type=public \
    --ssh-public-key=~/.ssh/id_rsa.pub \
    --dry-run \
    -o yaml > cluster-config.yaml

echo -e "${YELLOW}Modifying cluster configuration for single node...${NC}"
# Add spot instance configuration and other customizations
cat > patch.yaml << EOF
spec:
  cloudConfig:
    spotinstControllerEnabled: true
  iam:
    allowContainerRegistry: true
  docker:
    skipInstall: false
EOF

# Merge configurations
yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' cluster-config.yaml patch.yaml > cluster-config-final.yaml

# Create the cluster
echo -e "${YELLOW}Creating cluster...${NC}"
kops create -f cluster-config-final.yaml
kops create secret --name $FULL_CLUSTER_NAME sshpublickey admin -i ~/.ssh/id_rsa.pub

echo -e "${YELLOW}Updating cluster...${NC}"
kops update cluster --name $FULL_CLUSTER_NAME --yes

# Create cleanup script
cat > cleanup-${CLUSTER_NAME}.sh << EOL
#!/bin/bash
echo "Cleaning up resources..."
kops delete cluster --name ${FULL_CLUSTER_NAME} --yes
aws s3 rb s3://${BUCKET_NAME} --force
echo "Cleanup complete"
EOL

chmod +x cleanup-${CLUSTER_NAME}.sh

echo -e "${GREEN}=== Setup Complete ===${NC}"
echo -e "${GREEN}Cluster name: $FULL_CLUSTER_NAME${NC}"
echo -e "${GREEN}State store: $KOPS_STATE_STORE${NC}"
echo -e "${YELLOW}Wait ~10 minutes for the cluster to be ready${NC}"
echo -e "${YELLOW}Run 'kops validate cluster' to check status${NC}"
echo -e "${YELLOW}Cleanup script created: cleanup-${CLUSTER_NAME}.sh${NC}"
