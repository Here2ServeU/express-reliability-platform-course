#!/usr/bin/env bash
# Send a Slack alert via Incoming Webhook.
#
# Required (one of):
#   SLACK_WEBHOOK_URL env var         - preferred (keeps URL out of command history)
#   --url argument                    - fallback for ad-hoc use
#
# Usage:
#   SLACK_WEBHOOK_URL=https://hooks.slack.com/services/... \
#     ./slack/send_slack_webhook.sh --message "SEV1 on node-api"
#
#   ./slack/send_slack_webhook.sh \
#     --evidence-file artifacts/aiops/evidence/local/INC-001.json
#
#   ./slack/send_slack_webhook.sh --dry-run \
#     --evidence-file artifacts/aiops/evidence/local/INC-001.json
#
# To get a Webhook URL:
#   1. Go to https://api.slack.com/apps -> Create New App -> From Scratch
#   2. Enable Incoming Webhooks, click Add New Webhook to Workspace
#   3. Choose a channel, copy the URL, export it as SLACK_WEBHOOK_URL
set -euo pipefail

WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
MESSAGE=""
EVIDENCE_FILE=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)            WEBHOOK_URL="$2"; shift 2 ;;
    --message)        MESSAGE="$2";     shift 2 ;;
    --evidence-file)  EVIDENCE_FILE="$2"; shift 2 ;;
    --dry-run)        DRY_RUN=true;    shift ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

# Build message from evidence JSON if provided
if [[ -n "$EVIDENCE_FILE" ]]; then
  if ! command -v python3 &>/dev/null; then
    echo "python3 is required to parse evidence files. Install it or use --message." >&2
    exit 1
  fi
  MESSAGE=$(python3 - <<PYEOF
import json, sys
with open("$EVIDENCE_FILE") as f:
    e = json.load(f)
sev = e.get("severity", "unknown").upper()
icon = ":rotating_light:" if sev == "HIGH" else (":warning:" if sev == "MEDIUM" else ":white_check_mark:")
print(
    f"{icon} *AIOps Alert*\\n"
    f"*Incident:* {e.get('incident_id', 'N/A')}\\n"
    f"*Service:* {e.get('service', 'N/A')}\\n"
    f"*Severity:* {sev}\\n"
    f"*Risk Score:* {e.get('risk_score', 'N/A')}\\n"
    f"*Action:* {e.get('recommended_action', 'N/A')}\\n"
    f"*Owner:* {e.get('owner', 'N/A')}\\n"
    f"*Generated:* {e.get('generated_at_utc', 'N/A')}"
)
PYEOF
)
fi

if [[ -z "$MESSAGE" ]]; then
  MESSAGE="Alert from Express Reliability Platform V8"
fi

if [[ "$DRY_RUN" == "true" ]] || [[ -z "$WEBHOOK_URL" ]]; then
  echo "[DRY RUN] Slack message:"
  echo "$MESSAGE"
  if [[ -z "$WEBHOOK_URL" ]]; then
    echo ""
    echo "Set SLACK_WEBHOOK_URL to send for real."
  fi
  exit 0
fi

curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  --data "$(python3 -c "import json,sys; print(json.dumps({'text': sys.stdin.read()}))" <<< "$MESSAGE")"

echo ""
echo "Slack alert sent."
