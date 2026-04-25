#!/bin/bash
set -e

echo "=== V6 Cleanup ==="

echo "Step 1: Uninstall Helm releases..."
helm uninstall web-ui node-api flask-api -n platform 2>/dev/null || true
kubectl delete namespace platform 2>/dev/null || true

echo "Step 2: Destroy EKS Terraform (10-15 minutes)..."
terraform -chdir=terraform/eks destroy -auto-approve

echo "Step 3: Remove kubectl context..."
CTX=$(kubectl config current-context 2>/dev/null || true)
if [ -n "$CTX" ]; then
  kubectl config delete-context "$CTX" 2>/dev/null || true
fi

echo "=== Done! Bootstrap S3 + DynamoDB kept for V7-V10 ==="
