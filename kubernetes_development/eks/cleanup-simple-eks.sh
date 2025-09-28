#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

CLUSTER_NAME="${1:-simple-eks-cluster}"
REGION="${2:-eu-west-1}"

echo -e "${YELLOW}=== Cleaning up EKS Cluster ===${NC}"
echo -e "${YELLOW}Cluster Name: $CLUSTER_NAME${NC}"
echo -e "${YELLOW}Region: $REGION${NC}"

# Delete sample applications first
echo -e "${YELLOW}Cleaning up sample applications...${NC}"
kubectl delete -f sample-app-with-storage.yaml --ignore-not-found=true

# Delete ALB ingresses to clean up load balancers
echo -e "${YELLOW}Cleaning up ingresses and load balancers...${NC}"
kubectl delete ingress --all --all-namespaces --ignore-not-found=true

# Wait a bit for load balancers to be cleaned up
echo -e "${YELLOW}Waiting for load balancers to be cleaned up...${NC}"
sleep 30

# Delete the cluster
echo -e "${YELLOW}Deleting EKS cluster...${NC}"
eksctl delete cluster --name $CLUSTER_NAME --region $REGION --wait

echo -e "${GREEN}=== Cleanup Complete ===${NC}"
echo -e "${GREEN}Cluster $CLUSTER_NAME has been deleted${NC}"
