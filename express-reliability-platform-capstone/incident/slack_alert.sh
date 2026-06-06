#!/usr/bin/env bash
set -euo pipefail

SEVERITY="${1:-INFO}"
TITLE="${2:-Reliability alert}"
MESSAGE="${3:-No message supplied}"

payload=$(printf '{"text":"[%s] %s\n%s"}' "$SEVERITY" "$TITLE" "$MESSAGE")

if [ -z "${SLACK_WEBHOOK_URL:-}" ]; then
  echo "[DRY RUN] Slack payload:"
  echo "$payload"
  exit 0
fi

curl -sS -X POST -H "Content-Type: application/json" --data "$payload" "$SLACK_WEBHOOK_URL"
echo
