#!/bin/bash
set -e

echo "=== V7 Cleanup (reverse order) ==="

echo "Step 1: Uninstall Helm releases..."
helm uninstall web-ui node-api flask-api -n platform 2>/dev/null || true
kubectl delete namespace platform 2>/dev/null || true

echo "Step 2: Destroy live layer (EKS - 10-15 min)..."
terraform -chdir=terraform/live destroy -auto-approve

echo "Step 3: Destroy shared layer (VPC)..."
terraform -chdir=terraform/shared destroy -auto-approve

echo "Step 4: Remove kubectl context..."
CTX=$(kubectl config current-context 2>/dev/null || true)
if [ -n "$CTX" ]; then
  kubectl config delete-context "$CTX" 2>/dev/null || true
fi

echo "=== Done! Bootstrap S3 + DynamoDB kept for V8-V10 ==="
