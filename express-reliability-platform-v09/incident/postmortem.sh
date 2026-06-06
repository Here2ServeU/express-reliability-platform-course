#!/usr/bin/env bash
set -euo pipefail

INCIDENT_ID="${INCIDENT_ID:-INC-UNKNOWN}"
SERVICE="${SERVICE:-unknown-service}"
IMPACT="${IMPACT:-Impact not recorded}"
ROOT_CAUSE="${ROOT_CAUSE:-Root cause pending}"
RECOVERY_TIME="${RECOVERY_TIME:-unknown}"
FOLLOW_UP="${FOLLOW_UP:-Add follow-up action}"

report="Postmortem $INCIDENT_ID
Service: $SERVICE
Impact: $IMPACT
Root cause: $ROOT_CAUSE
Recovery time: $RECOVERY_TIME
Follow-up: $FOLLOW_UP"

echo "$report"

if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
  ./incident/slack_alert.sh INFO "Postmortem $INCIDENT_ID" "$report"
fi
