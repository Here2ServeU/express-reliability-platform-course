#!/usr/bin/env bash
set -euo pipefail

echo "Removing V8 governance policies..."
kubectl delete -f governance/gatekeeper/constraints --ignore-not-found=true || true
kubectl delete -f governance/gatekeeper/templates --ignore-not-found=true || true
kubectl delete namespace gatekeeper-system --ignore-not-found=true || true

echo "Run the V7 cleanup steps next if you also want to destroy AWS resources."
