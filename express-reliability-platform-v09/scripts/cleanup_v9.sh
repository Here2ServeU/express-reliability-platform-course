#!/usr/bin/env bash
set -euo pipefail

echo "Cleaning V9 incident pipeline resources..."
kubectl delete -f governance/gatekeeper/constraints --ignore-not-found=true || true
kubectl delete -f governance/gatekeeper/templates --ignore-not-found=true || true
kubectl delete namespace gatekeeper-system --ignore-not-found=true || true
echo "Run Terraform destroy for live, shared, and bootstrap layers when you are ready."
