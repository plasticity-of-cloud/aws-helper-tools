#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
CLUSTER_NAME="${1:-local.k8s.local}"
REGION="${2:-eu-west-1}"
AZ="${REGION}a"
STATE_BUCKET="${3:-kops-state-$(date +%s)}"

echo -e "${GREEN}=== Setting up Local Kops Cluster ===${NC}"
echo -e "${GREEN}Cluster Name: $CLUSTER_NAME${NC}"
echo -e "${GREEN}Region: $REGION${NC}"
echo -e "${GREEN}State Bucket: $STATE_BUCKET${NC}"

# Install kops for ARM64
if ! command -v kops &> /dev/null; then
    echo -e "${YELLOW}Installing kops for ARM64...${NC}"
    curl -Lo kops https://github.com/kubernetes/kops/releases/download/$(curl -s https://api.github.com/repos/kubernetes/kops/releases/latest | grep tag_name | cut -d '"' -f 4)/kops-linux-arm64
    chmod +x kops && sudo mv kops /usr/local/bin/
fi

# Install kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${YELLOW}Installing kubectl for ARM64...${NC}"
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl"
    chmod +x kubectl && sudo mv kubectl /usr/local/bin/
fi

# Install helm
if ! command -v helm &> /dev/null; then
    echo -e "${YELLOW}Installing helm...${NC}"
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Create S3 bucket for kops state
echo -e "${YELLOW}Creating S3 bucket for kops state...${NC}"
aws s3 mb s3://$STATE_BUCKET --region $REGION || echo "Bucket might already exist"

# Export kops environment
export KOPS_STATE_STORE=s3://$STATE_BUCKET
export KOPS_CLUSTER_NAME=$CLUSTER_NAME

# Create cluster configuration (control plane only, no worker nodes initially)
echo -e "${YELLOW}Creating kops cluster configuration...${NC}"
kops create cluster \
    --name=$CLUSTER_NAME \
    --state=s3://$STATE_BUCKET \
    --zones=$AZ \
    --control-plane-count=1 \
    --control-plane-size=t4g.small \
    --node-count=0 \
    --networking=cilium \
    --cloud-provider=aws \
    --yes

# Wait for cluster to be ready
echo -e "${YELLOW}Waiting for cluster to be ready...${NC}"
kops validate cluster --wait 10m

# Update kubeconfig
kops export kubeconfig --admin

echo -e "${YELLOW}Installing EBS CSI Driver...${NC}"
# Install EBS CSI Driver
kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.25"

# Create storage class
cat <<EOF | kubectl apply -f -
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
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF

echo -e "${YELLOW}Installing AWS Load Balancer Controller...${NC}"
# Install AWS Load Balancer Controller
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Create IAM policy for ALB controller
cat > alb-iam-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "iam:CreateServiceLinkedRole",
                "ec2:DescribeAccountAttributes",
                "ec2:DescribeAddresses",
                "ec2:DescribeAvailabilityZones",
                "ec2:DescribeInternetGateways",
                "ec2:DescribeVpcs",
                "ec2:DescribeSubnets",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeInstances",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DescribeTags",
                "ec2:GetCoipPoolUsage",
                "ec2:DescribeCoipPools",
                "elasticloadbalancing:DescribeLoadBalancers",
                "elasticloadbalancing:DescribeLoadBalancerAttributes",
                "elasticloadbalancing:DescribeListeners",
                "elasticloadbalancing:DescribeListenerCertificates",
                "elasticloadbalancing:DescribeSSLPolicies",
                "elasticloadbalancing:DescribeRules",
                "elasticloadbalancing:DescribeTargetGroups",
                "elasticloadbalancing:DescribeTargetGroupAttributes",
                "elasticloadbalancing:DescribeTargetHealth",
                "elasticloadbalancing:DescribeTags"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "cognito-idp:DescribeUserPoolClient",
                "acm:ListCertificates",
                "acm:DescribeCertificate",
                "iam:ListServerCertificates",
                "iam:GetServerCertificate",
                "waf-regional:GetWebACL",
                "waf-regional:GetWebACLForResource",
                "waf-regional:AssociateWebACL",
                "waf-regional:DisassociateWebACL",
                "wafv2:GetWebACL",
                "wafv2:GetWebACLForResource",
                "wafv2:AssociateWebACL",
                "wafv2:DisassociateWebACL",
                "shield:DescribeProtection",
                "shield:GetSubscriptionState",
                "shield:DescribeSubscription",
                "shield:CreateProtection",
                "shield:DeleteProtection"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupIngress"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateSecurityGroup"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateTags"
            ],
            "Resource": "arn:aws:ec2:*:*:security-group/*",
            "Condition": {
                "StringEquals": {
                    "ec2:CreateAction": "CreateSecurityGroup"
                },
                "Null": {
                    "aws:RequestedRegion": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:CreateLoadBalancer",
                "elasticloadbalancing:CreateTargetGroup"
            ],
            "Resource": "*",
            "Condition": {
                "Null": {
                    "aws:RequestedRegion": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:CreateListener",
                "elasticloadbalancing:DeleteListener",
                "elasticloadbalancing:CreateRule",
                "elasticloadbalancing:DeleteRule"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:AddTags",
                "elasticloadbalancing:RemoveTags"
            ],
            "Resource": [
                "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
                "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
                "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
            ],
            "Condition": {
                "Null": {
                    "aws:RequestedRegion": "false",
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:ModifyLoadBalancerAttributes",
                "elasticloadbalancing:SetIpAddressType",
                "elasticloadbalancing:SetSecurityGroups",
                "elasticloadbalancing:SetSubnets",
                "elasticloadbalancing:DeleteLoadBalancer",
                "elasticloadbalancing:ModifyTargetGroup",
                "elasticloadbalancing:ModifyTargetGroupAttributes",
                "elasticloadbalancing:DeleteTargetGroup"
            ],
            "Resource": "*",
            "Condition": {
                "Null": {
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:RegisterTargets",
                "elasticloadbalancing:DeregisterTargets"
            ],
            "Resource": "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:SetWebAcl",
                "elasticloadbalancing:ModifyListener",
                "elasticloadbalancing:AddListenerCertificates",
                "elasticloadbalancing:RemoveListenerCertificates",
                "elasticloadbalancing:ModifyRule"
            ],
            "Resource": "*"
        }
    ]
}
EOF

# Install ALB controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller

echo -e "${GREEN}=== Local Kops Cluster Setup Complete ===${NC}"
echo -e "${GREEN}Cluster Name: $CLUSTER_NAME${NC}"
echo -e "${GREEN}State Store: s3://$STATE_BUCKET${NC}"

echo -e "${YELLOW}Cluster status:${NC}"
kubectl get nodes
kubectl get pods -n kube-system

echo -e "${GREEN}=== Next Steps ===${NC}"
echo -e "${YELLOW}1. Add worker nodes with kops:${NC}"
echo -e "   kops create instancegroup nodes --name=$CLUSTER_NAME --state=s3://$STATE_BUCKET"
echo -e "   kops update cluster --name=$CLUSTER_NAME --state=s3://$STATE_BUCKET --yes"
echo -e ""
echo -e "${YELLOW}2. Or install Karpenter for auto-scaling:${NC}"
echo -e "   # See setup-karpenter.sh"
echo -e ""
echo -e "${YELLOW}3. Test with sample app:${NC}"
echo -e "   kubectl apply -f sample-app-with-storage.yaml"
echo -e ""
echo -e "${YELLOW}4. Cleanup:${NC}"
echo -e "   ./cleanup-local-kops.sh $CLUSTER_NAME $STATE_BUCKET"

# Save cluster info
echo "export KOPS_STATE_STORE=s3://$STATE_BUCKET" > cluster-env.sh
echo "export KOPS_CLUSTER_NAME=$CLUSTER_NAME" >> cluster-env.sh
echo -e "${YELLOW}Cluster environment saved to cluster-env.sh${NC}"
echo -e "${YELLOW}Source it with: source cluster-env.sh${NC}"
