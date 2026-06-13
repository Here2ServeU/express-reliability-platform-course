#!/bin/bash
set -e

SLACK_WEBHOOK_URL=${SLACK_WEBHOOK_URL:-'YOUR_SLACK_WEBHOOK_URL'}
SEVERITY=${1:-'INFO'}
TITLE=${2:-'Reliability Platform Alert'}
MESSAGE=${3:-'An alert was fired from the reliability platform.'}
SERVICE=${4:-'unknown'}

# Choose emoji based on severity
case $SEVERITY in
  CRITICAL) EMOJI=':rotating_light:' ; COLOR='#FF0000' ;;
  HIGH)     EMOJI=':warning:'        ; COLOR='#FF6600' ;;
  MEDIUM)   EMOJI=':bell:'           ; COLOR='#FFCC00' ;;
  INFO)     EMOJI=':information_source:' ; COLOR='#36A64F' ;;
  RESOLVED) EMOJI=':white_check_mark:'   ; COLOR='#36A64F' ;;
  *)        EMOJI=':bell:'           ; COLOR='#808080' ;;
esac

TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

PAYLOAD=$(cat <<JSON
{
  "attachments": [{
    "color": "${COLOR}",
    "title": "${EMOJI} ${TITLE}",
    "text": "*Severity:* ${SEVERITY}\n*Service:* ${SERVICE}\n*Message:* ${MESSAGE}\n*Time:* ${TIMESTAMP}",
    "footer": "Reliability Platform V9",
    "ts": $(date +%s)
  }]
}
JSON
)

HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' \
  -X POST \
  -H 'Content-Type: application/json' \
  -d "$PAYLOAD" \
  "$SLACK_WEBHOOK_URL")

if [ "$HTTP_CODE" -eq 200 ]; then
  echo "Slack alert sent successfully (HTTP ${HTTP_CODE})"
else
  echo "ERROR: Slack alert failed (HTTP ${HTTP_CODE})"
  exit 1
fi
