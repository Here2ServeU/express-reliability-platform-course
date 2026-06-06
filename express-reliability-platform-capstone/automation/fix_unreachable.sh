#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-platform}"
SERVICE_URL="${SERVICE_URL:-http://localhost:8080/health}"
DEPLOYMENT="${DEPLOYMENT:-web-ui}"

if curl -fsS "$SERVICE_URL" >/dev/null; then
  echo "$SERVICE_URL is reachable."
  exit 0
fi

kubectl rollout restart "deployment/$DEPLOYMENT" -n "$NAMESPACE"
./incident/slack_alert.sh CRITICAL "Auto-recovery restarted $DEPLOYMENT" "$SERVICE_URL failed health check."
