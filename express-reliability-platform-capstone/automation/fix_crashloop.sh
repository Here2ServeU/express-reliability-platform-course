#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-platform}"

pod=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | awk '/CrashLoopBackOff/ {print $1; exit}')
if [ -z "$pod" ]; then
  echo "No CrashLoopBackOff pods found."
  exit 0
fi

deployment=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.metadata.labels.app}')
kubectl rollout restart "deployment/$deployment" -n "$NAMESPACE"
./incident/slack_alert.sh CRITICAL "Auto-recovery restarted $deployment" "$pod was in CrashLoopBackOff."
