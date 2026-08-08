#!/bin/bash
NAMESPACE=${NAMESPACE:-"platform"}
SLACK_WEBHOOK_URL=${SLACK_WEBHOOK_URL:-"YOUR_SLACK_WEBHOOK_URL"}

check_service() {
  local SERVICE=$1 PORT=$2 FAILURES=0
  for i in 1 2 3; do
    STATUS=$(kubectl exec -n "$NAMESPACE" deploy/"$SERVICE" -- \
      curl -s -o /dev/null -w "%{http_code}" \
      http://localhost:"$PORT"/health 2>/dev/null || echo "000")
    if [ "$STATUS" != "200" ]; then
      FAILURES=$((FAILURES + 1))
      echo "  $SERVICE health check $i: HTTP $STATUS"
      sleep 5
    else
      echo "  $SERVICE health check $i: OK"
      return 0
    fi
  done
  if [ "$FAILURES" -ge 3 ]; then
    POD=$(kubectl get pods -n "$NAMESPACE" -l app="$SERVICE" \
      --no-headers | head -1 | awk '{print $1}')
    kubectl delete pod "$POD" -n "$NAMESPACE"
    bash incident/slack_alert.sh CRITICAL "Auto-Recovery" \
      "$SERVICE failed 3 health checks. Deleted $POD. Kubernetes is replacing it."
    echo "Deleted $POD. Kubernetes will replace it."
  fi
}

echo "=== Health Check Watcher ==="
check_service "flask-api" 5000
check_service "node-api" 3000
check_service "web-ui" 8080
