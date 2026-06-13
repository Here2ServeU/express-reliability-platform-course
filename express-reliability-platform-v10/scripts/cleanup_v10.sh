#!/bin/bash
set -e
echo '=== V10 Cleanup ==='

# Step 1: Remove OPA Gatekeeper (must happen before cluster destroy)
echo 'Step 1: Removing OPA Gatekeeper...'
kubectl delete -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/v3.14.0/deploy/gatekeeper.yaml \
  --ignore-not-found 2>/dev/null || true

# Wait for webhook to be removed (prevents kubectl timeout during cleanup)
kubectl delete validatingwebhookconfiguration gatekeeper-validating-webhook-configuration \
  --ignore-not-found 2>/dev/null || true
sleep 15

# Step 2: Remove Helm releases and namespace
echo 'Step 2: Uninstalling Helm releases...'
helm uninstall web-ui node-api flask-api -n platform 2>/dev/null || true
kubectl delete namespace platform --ignore-not-found 2>/dev/null || true

# Step 3: Reap orphan load balancers
echo 'Step 3: Reaping orphan load balancers...'
VPC_ID=$(terraform -chdir=terraform/shared output -raw vpc_id 2>/dev/null || echo '')
if [ -n "$VPC_ID" ]; then
  for LB in $(aws elb describe-load-balancers --region us-east-1 \
        --query "LoadBalancerDescriptions[?VPCId=='${VPC_ID}'].LoadBalancerName" \
        --output text); do
    aws elb delete-load-balancer --load-balancer-name "$LB" --region us-east-1
  done
  sleep 90
fi

# Step 4: Destroy live (EKS)
echo 'Step 4: Destroying live layer (EKS — 10-15 min)...'
BUCKET=$(terraform -chdir=terraform/bootstrap output -raw state_bucket 2>/dev/null || echo '')
[ -n "$BUCKET" ] && terraform -chdir=terraform/live destroy -auto-approve -var "state_bucket=${BUCKET}"

# Step 5: Destroy shared (VPC)
echo 'Step 5: Destroying shared layer (VPC)...'
terraform -chdir=terraform/shared destroy -auto-approve

# Step 6: Drain bucket and destroy bootstrap
echo 'Step 6: Draining state bucket and destroying bootstrap...'
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
aws s3 rm s3://reliability-platform-v08-tfstate-${ACCOUNT} --recursive 2>/dev/null || true
terraform -chdir=terraform/bootstrap destroy -auto-approve

# Step 7: Remove kubectl context
kubectl config delete-context $(kubectl config current-context) 2>/dev/null || true

echo '=== V10 cleanup complete ==='
