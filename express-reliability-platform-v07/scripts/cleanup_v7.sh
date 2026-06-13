#!/bin/bash
set -e
echo '=== V7 Cleanup: reverse order ==='

# Step 1: Remove Kubernetes resources (releases the Classic ELB)
echo 'Step 1: Uninstalling Helm releases and deleting namespace...'
helm uninstall web-ui node-api flask-api -n platform 2>/dev/null || true
kubectl delete namespace platform --ignore-not-found 2>/dev/null || true

# Step 2: Reap orphan Classic ELB from web-ui Service
echo 'Step 2: Reaping orphan load balancers (prevents VPC delete failure)...'
VPC_ID=$(terraform -chdir=terraform/shared output -raw vpc_id 2>/dev/null || echo '')
if [ -n "$VPC_ID" ]; then
  for LB in $(aws elb describe-load-balancers --region us-east-1 \
        --query "LoadBalancerDescriptions[?VPCId=='${VPC_ID}'].LoadBalancerName" \
        --output text); do
    aws elb delete-load-balancer --load-balancer-name "$LB" --region us-east-1
    echo "Deleted orphan ELB: $LB"
  done
  sleep 90
fi

# Step 3: Destroy live layer (EKS cluster — 10-15 minutes)
echo 'Step 3: Destroying live layer (EKS)...'
BUCKET=$(terraform -chdir=terraform/bootstrap output -raw state_bucket 2>/dev/null || echo '')
if [ -n "$BUCKET" ]; then
  terraform -chdir=terraform/live destroy -auto-approve \
    -var "state_bucket=${BUCKET}"
fi

# Step 4: Destroy shared layer (VPC)
echo 'Step 4: Destroying shared layer (VPC)...'
terraform -chdir=terraform/shared destroy -auto-approve

# Step 5: Drain the V7 state bucket and destroy bootstrap
echo 'Step 5: Draining state bucket and destroying bootstrap...'
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
aws s3 rm s3://reliability-platform-v07-tfstate-${ACCOUNT} --recursive
terraform -chdir=terraform/bootstrap destroy -auto-approve

# Step 6: Remove kubectl context
echo 'Step 6: Removing stale kubectl context...'
kubectl config delete-context $(kubectl config current-context) 2>/dev/null || true

echo '=== V7 cleanup complete. V5 and V6 bootstraps untouched. ==='
