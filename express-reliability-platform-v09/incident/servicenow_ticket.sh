#!/usr/bin/env bash
set -euo pipefail

SHORT_DESCRIPTION="${1:-Reliability incident detected}"
URGENCY="${2:-2}"

if [ -z "${SN_INSTANCE:-}" ] || [ -z "${SN_USER:-}" ] || [ -z "${SN_PASS:-}" ]; then
  echo "[DRY RUN] ServiceNow incident: $SHORT_DESCRIPTION urgency=$URGENCY"
  exit 0
fi

curl -sS -u "$SN_USER:$SN_PASS" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X POST "https://$SN_INSTANCE.service-now.com/api/now/table/incident" \
  --data "{\"short_description\":\"$SHORT_DESCRIPTION\",\"urgency\":\"$URGENCY\",\"impact\":\"$URGENCY\",\"category\":\"software\"}"
echo
