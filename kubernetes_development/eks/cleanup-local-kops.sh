#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

CLUSTER_NAME="${1}"
STATE_BUCKET="${2}"

if [ -z "$CLUSTER_NAME" ] || [ -z "$STATE_BUCKET" ]; then
    echo -e "${RED}Usage: $0 <cluster-name> <state-bucket>${NC}"
    echo -e "${YELLOW}Example: $0 local.k8s.local kops-state-1234567890${NC}"
    exit 1
fi

echo -e "${YELLOW}=== Cleaning up Local Kops Cluster ===${NC}"
echo -e "${YELLOW}Cluster Name: $CLUSTER_NAME${NC}"
echo -e "${YELLOW}State Bucket: $STATE_BUCKET${NC}"

# Set environment
export KOPS_STATE_STORE=s3://$STATE_BUCKET
export KOPS_CLUSTER_NAME=$CLUSTER_NAME

# Delete test workloads
echo -e "${YELLOW}Cleaning up test workloads...${NC}"
kubectl delete deployment inflate --ignore-not-found=true
kubectl delete -f sample-app-with-storage.yaml --ignore-not-found=true

# Delete Karpenter resources
echo -e "${YELLOW}Cleaning up Karpenter...${NC}"
kubectl delete nodepool --all --ignore-not-found=true
kubectl delete ec2nodeclass --all --ignore-not-found=true
helm uninstall karpenter -n karpenter --ignore-not-found=true
kubectl delete namespace karpenter --ignore-not-found=true

# Wait for nodes to be cleaned up
echo -e "${YELLOW}Waiting for Karpenter nodes to be cleaned up...${NC}"
sleep 30

# Delete the cluster
echo -e "${YELLOW}Deleting kops cluster...${NC}"
kops delete cluster --name $CLUSTER_NAME --state s3://$STATE_BUCKET --yes

# Delete state bucket
echo -e "${YELLOW}Deleting state bucket...${NC}"
aws s3 rb s3://$STATE_BUCKET --force

# Clean up local files
rm -f cluster-env.sh alb-iam-policy.json

echo -e "${GREEN}=== Cleanup Complete ===${NC}"
echo -e "${GREEN}Cluster $CLUSTER_NAME has been deleted${NC}"
echo -e "${GREEN}State bucket s3://$STATE_BUCKET has been deleted${NC}"
