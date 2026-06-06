#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-platform}"
DEPLOYMENT="${DEPLOYMENT:-node-api}"
MAX_REPLICAS="${MAX_REPLICAS:-6}"

current=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}')
next=$((current + 1))

if [ "$next" -gt "$MAX_REPLICAS" ]; then
  echo "$DEPLOYMENT is already at max replicas ($MAX_REPLICAS)."
  exit 0
fi

kubectl scale deployment "$DEPLOYMENT" -n "$NAMESPACE" --replicas "$next"
./incident/slack_alert.sh WARNING "Auto-recovery scaled $DEPLOYMENT" "Replicas increased from $current to $next."
