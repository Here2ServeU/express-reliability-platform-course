#!/bin/bash
set -e
NAMESPACE=${NAMESPACE:-"platform"}
SLACK_WEBHOOK_URL=${SLACK_WEBHOOK_URL:-"YOUR_SLACK_WEBHOOK_URL"}
SN_INSTANCE=${SN_INSTANCE:-"devXXXXXX"}
SN_USER=${SN_USER:-"admin"}
SN_PASS=${SN_PASS:-"YOUR_SN_PASSWORD"}

echo "=== CrashLoop Watcher ==="

# Find any pod in CrashLoopBackOff
CRASH_POD=$(kubectl get pods -n "$NAMESPACE" --no-headers \
  | grep "CrashLoopBackOff" | head -1 | awk '{print $1}')

if [ -z "$CRASH_POD" ]; then
  echo "No CrashLoopBackOff pods. All healthy."
  exit 0
fi

DEPLOYMENT=$(kubectl get pod "$CRASH_POD" -n "$NAMESPACE" \
  -o jsonpath="{.metadata.labels.app}")

echo "Found crash loop: $CRASH_POD (deployment: $DEPLOYMENT)"

# Restart the deployment
kubectl rollout restart deployment/"$DEPLOYMENT" -n "$NAMESPACE"

# Notify Slack
bash incident/slack_alert.sh CRITICAL "Auto-Recovery" \
  "$CRASH_POD was in CrashLoopBackOff. Restarted $DEPLOYMENT automatically."

# Create a ServiceNow ticket
SN_INSTANCE=$SN_INSTANCE SN_USER=$SN_USER SN_PASS=$SN_PASS \
  bash incident/servicenow_ticket.sh \
  "CrashLoopBackOff: $DEPLOYMENT auto-restarted" "2"

echo "Recovery complete."
