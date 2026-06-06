#!/usr/bin/env bash
set -euo pipefail

echo "Cleaning V10 automation and platform resources..."
pkill -f "automation/recovery_policy.sh" 2>/dev/null || true
kubectl delete -f governance/gatekeeper/constraints --ignore-not-found=true || true
kubectl delete -f governance/gatekeeper/templates --ignore-not-found=true || true
echo "Destroy AWS resources in reverse order: live, shared, bootstrap."
