#!/bin/bash
# cleanup_capstone.sh — remove every AWS resource in reverse order.
set -e
NAMESPACE="platform"
REGION="${AWS_REGION:-us-east-1}"

echo '=== Step 1: Remove OPA Gatekeeper ==='
kubectl delete -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/v3.14.0/deploy/gatekeeper.yaml --ignore-not-found 2>/dev/null || true
sleep 15

echo '=== Step 2: Uninstall Helm releases and namespace ==='
helm uninstall web-ui node-api flask-api -n "$NAMESPACE" 2>/dev/null || true
kubectl delete namespace "$NAMESPACE" --ignore-not-found 2>/dev/null || true

echo '=== Step 3: Reap orphaned load balancers ==='
VPC_ID=$(terraform -chdir=platform/terraform/shared output -raw vpc_id 2>/dev/null || echo '')
if [ -n "$VPC_ID" ]; then
  for LB in $(aws elb describe-load-balancers --region "$REGION" \
        --query "LoadBalancerDescriptions[?VPCId=='${VPC_ID}'].LoadBalancerName" --output text); do
    aws elb delete-load-balancer --load-balancer-name "$LB" --region "$REGION"
  done
  sleep 90
fi

echo '=== Step 4: Destroy live layer (EKS) ==='
BUCKET=$(terraform -chdir=platform/terraform/bootstrap output -raw state_bucket 2>/dev/null || echo '')
[ -n "$BUCKET" ] && terraform -chdir=platform/terraform/live destroy -auto-approve -var "state_bucket=${BUCKET}"

echo '=== Step 5: Destroy shared layer (VPC) ==='
terraform -chdir=platform/terraform/shared destroy -auto-approve

echo '=== Step 6: Drain state bucket and destroy bootstrap ==='
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
aws s3 rm "s3://reliability-platform-capstone-tfstate-${ACCOUNT}" --recursive 2>/dev/null || true
terraform -chdir=platform/terraform/bootstrap destroy -auto-approve

echo '=== Capstone cleanup complete ==='
