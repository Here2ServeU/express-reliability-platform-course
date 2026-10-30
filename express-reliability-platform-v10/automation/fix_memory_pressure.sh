#!/bin/bash
NAMESPACE=${NAMESPACE:-"platform"}
SLACK_WEBHOOK_URL=${SLACK_WEBHOOK_URL:-"YOUR_SLACK_WEBHOOK_URL"}
THRESHOLD=${THRESHOLD:-80}

echo "=== Memory Pressure Watcher ==="

kubectl top pods -n "$NAMESPACE" --no-headers | while read POD CPU MEM; do
  MEM_VALUE=$(echo "$MEM" | sed "s/Mi//")
  LIMIT=$(kubectl get pod "$POD" -n "$NAMESPACE" \
    -o jsonpath="{.spec.containers[0].resources.limits.memory}" \
    | sed "s/Mi//")

  if [ -n "$LIMIT" ] && [ "$MEM_VALUE" -gt 0 ] && [ "$LIMIT" -gt 0 ]; then
    PERCENT=$((MEM_VALUE * 100 / LIMIT))
    if [ "$PERCENT" -ge "$THRESHOLD" ]; then
      DEPLOYMENT=$(kubectl get pod "$POD" -n "$NAMESPACE" \
        -o jsonpath="{.metadata.labels.app}")
      CURRENT=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath="{.spec.replicas}")
      NEW=$((CURRENT + 1))
      kubectl scale deployment/"$DEPLOYMENT" \
        -n "$NAMESPACE" --replicas="$NEW"
      bash incident/slack_alert.sh HIGH "Auto-Recovery" \
        "$POD at ${PERCENT}% memory. Scaled $DEPLOYMENT to $NEW replicas."
      echo "Scaled $DEPLOYMENT from $CURRENT to $NEW."
    fi
  fi
done
