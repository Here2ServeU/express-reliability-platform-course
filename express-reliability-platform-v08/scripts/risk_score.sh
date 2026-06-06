#!/usr/bin/env bash
set -euo pipefail

CHANGED_FILES="${CHANGED_FILES:-0}"
TRIVY_HIGH="${TRIVY_HIGH:-0}"
TRIVY_CRITICAL="${TRIVY_CRITICAL:-0}"
CHECKOV_FAILED="${CHECKOV_FAILED:-0}"
ERROR_RATE_PCT="${ERROR_RATE_PCT:-0}"
DEPLOY_HOUR="${DEPLOY_HOUR:-$(date +%H)}"

score=0

if [ "$CHANGED_FILES" -gt 20 ]; then score=$((score + 20)); fi
if [ "$TRIVY_HIGH" -gt 0 ]; then score=$((score + 25)); fi
if [ "$TRIVY_CRITICAL" -gt 0 ]; then score=$((score + 50)); fi
if [ "$CHECKOV_FAILED" -gt 0 ]; then score=$((score + 20)); fi

error_int="${ERROR_RATE_PCT%.*}"
if [ "$error_int" -ge 5 ]; then score=$((score + 20)); fi
if [ "$DEPLOY_HOUR" -ge 16 ]; then score=$((score + 10)); fi

if [ "$score" -ge 80 ]; then
  decision="CRITICAL"
  action="BLOCK"
elif [ "$score" -ge 60 ]; then
  decision="HIGH"
  action="PAUSE_FOR_APPROVAL"
elif [ "$score" -ge 30 ]; then
  decision="MEDIUM"
  action="PROCEED_WITH_WATCH"
else
  decision="LOW"
  action="PROCEED"
fi

printf 'risk_score=%s\nrisk_level=%s\naction=%s\n' "$score" "$decision" "$action"

if [ "$action" = "BLOCK" ]; then
  exit 1
fi
