#!/bin/bash
# cleanup_capstone.sh: remove every Google Cloud resource in reverse order.
# Run this at the end of each lab session to keep cost near zero.
set -uo pipefail
: "${PROJECT_ID:?Set PROJECT_ID to your Google Cloud project ID}"
REGION="${REGION:-us-central1}"
NAMESPACE="platform"
TF_VARS=(-var "project_id=${PROJECT_ID}" -var "region=${REGION}")

echo '=== Step 1: Remove Gatekeeper ==='
kubectl delete -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/v3.14.0/deploy/gatekeeper.yaml --ignore-not-found 2>/dev/null || true

echo '=== Step 2: Uninstall Helm releases (releases the external load balancer) ==='
helm uninstall web-ui node-api flask-api -n "$NAMESPACE" 2>/dev/null || true
kubectl delete -f monitoring/gmp/ --ignore-not-found 2>/dev/null || true
kubectl delete namespace "$NAMESPACE" --ignore-not-found 2>/dev/null || true
sleep 60   # let GKE remove the load balancer's forwarding rules

BUCKET=$(terraform -chdir=platform/terraform/bootstrap output -raw state_bucket 2>/dev/null || echo '')
if [ -n "$BUCKET" ]; then
  echo '=== Step 3: Destroy live layer (GKE, SLOs) ==='
  terraform -chdir=platform/terraform/live destroy -auto-approve "${TF_VARS[@]}" -var "state_bucket=${BUCKET}"

  echo '=== Step 4: Destroy shared layer (VPC, NAT) ==='
  terraform -chdir=platform/terraform/shared destroy -auto-approve "${TF_VARS[@]}"
fi

echo '=== Step 5: Destroy bootstrap (state bucket, registry) ==='
terraform -chdir=platform/terraform/bootstrap destroy -auto-approve "${TF_VARS[@]}"

echo '=== Capstone cleanup complete ==='
