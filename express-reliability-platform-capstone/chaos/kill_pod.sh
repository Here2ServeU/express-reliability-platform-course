#!/bin/bash
set -e

NAMESPACE=${NAMESPACE:-'platform'}
SERVICE=${1:-'flask-api-flask-api'}
RECOVERY_SLO=${RECOVERY_SLO:-60}   # seconds

echo "=== Chaos Drill 1: Pod Kill ==="
echo "Target: ${SERVICE} in namespace ${NAMESPACE}"
echo "Recovery SLO: ${RECOVERY_SLO} seconds"

# Get a running pod name
POD=$(kubectl get pods -n "$NAMESPACE" -l app="$SERVICE" \
  -o jsonpath='{.items[0].metadata.name}')
echo "Killing pod: $POD"

# Record start time
START=$(date +%s)

# Kill the pod (simulating a crash)
kubectl delete pod "$POD" -n "$NAMESPACE" --grace-period=0 --force

# Wait until the replacement pod is Running and Ready
echo "Waiting for replacement pod to be Ready..."
kubectl wait --for=condition=ready pod \
  -l app="$SERVICE" -n "$NAMESPACE" \
  --timeout=120s

# Record end time and calculate recovery time
END=$(date +%s)
RECOVERY_TIME=$((END - START))

echo "Recovery time: ${RECOVERY_TIME} seconds"

# Compare to SLO
if [ "$RECOVERY_TIME" -le "$RECOVERY_SLO" ]; then
  RESULT="PASSED"
  echo "DRILL PASSED: recovered in ${RECOVERY_TIME}s (SLO: ${RECOVERY_SLO}s)"
else
  RESULT="FAILED"
  echo "DRILL FAILED: recovered in ${RECOVERY_TIME}s (SLO: ${RECOVERY_SLO}s)"
fi

# Post result to Slack
SLACK_WEBHOOK_URL=${SLACK_WEBHOOK_URL:-''} \
  ./incident/slack_alert.sh INFO \
  "Chaos Drill 1: Pod Kill - ${RESULT}" \
  "Service: ${SERVICE} | Recovery: ${RECOVERY_TIME}s | SLO: ${RECOVERY_SLO}s" \
  "chaos-drill"
