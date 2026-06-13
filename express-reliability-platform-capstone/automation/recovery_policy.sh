#!/bin/bash
NAMESPACE=${NAMESPACE:-"platform"}
SLACK_WEBHOOK_URL=${SLACK_WEBHOOK_URL:-"YOUR_SLACK_WEBHOOK_URL"}
SN_INSTANCE=${SN_INSTANCE:-"devXXXXXX"}
SN_USER=${SN_USER:-"admin"}
SN_PASS=${SN_PASS:-"YOUR_SN_PASSWORD"}
INTERVAL=${INTERVAL:-30}

echo "=== Recovery Policy: starting watch loop ==="
echo "Namespace: $NAMESPACE  Interval: ${INTERVAL}s"
echo "Press Ctrl+C to stop."

chmod +x automation/fix_crashloop.sh
chmod +x automation/fix_memory_pressure.sh
chmod +x automation/fix_unreachable.sh

while true; do
  echo ""
  echo "--- $(date "+%Y-%m-%d %H:%M:%S") Check ---"

  NAMESPACE=$NAMESPACE \
    SLACK_WEBHOOK_URL=$SLACK_WEBHOOK_URL \
    SN_INSTANCE=$SN_INSTANCE SN_USER=$SN_USER SN_PASS=$SN_PASS \
    bash automation/fix_crashloop.sh

  NAMESPACE=$NAMESPACE \
    SLACK_WEBHOOK_URL=$SLACK_WEBHOOK_URL \
    bash automation/fix_memory_pressure.sh

  NAMESPACE=$NAMESPACE \
    SLACK_WEBHOOK_URL=$SLACK_WEBHOOK_URL \
    bash automation/fix_unreachable.sh

  echo "--- Check complete. Sleeping ${INTERVAL}s ---"
  sleep "$INTERVAL"
done
