#!/usr/bin/env bash
# Advanced chaos drill: inject a controlled failure, score it with AIOps,
# send a Slack alert, and open ITSM tickets in ServiceNow and Jira.
#
# This is the full pipeline:
#   Chaos Injection -> AIOps Risk Score -> Slack Alert -> ServiceNow Ticket -> Jira Issue
#
# Usage:
#   ./chaos/run_chaos_drill.sh <incident_id> <service> <experiment>
#
# Experiments:
#   latency      - Simulate 1200ms API latency
#   error_rate   - Simulate 8% error rate
#   pod_kill     - Simulate pod kill with multi-service fallout
#   cpu_stress   - Simulate CPU saturation with elevated latency
#
# Examples:
#   ./chaos/run_chaos_drill.sh INC-CHAOS-001 node-api latency
#   ./chaos/run_chaos_drill.sh INC-CHAOS-002 flask-api error_rate
#
# Environment variables (optional — scripts will use --dry-run if unset):
#   SLACK_WEBHOOK_URL  - Slack Incoming Webhook URL
#   SNOW_INSTANCE      - ServiceNow instance name
#   SNOW_USER          - ServiceNow username
#   SNOW_PASSWORD      - ServiceNow password
#   JIRA_BASE_URL      - Jira base URL
#   JIRA_USER          - Jira account email
#   JIRA_API_TOKEN     - Jira API token
#   JIRA_PROJECT       - Jira project key (default: OPS)
set -euo pipefail

INCIDENT_ID="${1:-INC-CHAOS-001}"
SERVICE="${2:-node-api}"
EXPERIMENT="${3:-latency}"

EVIDENCE_DIR="artifacts/aiops/evidence/chaos"
EVIDENCE_FILE="$EVIDENCE_DIR/${INCIDENT_ID}.json"
SCORE_SCRIPT="scripts/aiops_score_and_summarize.sh"
SLACK_SCRIPT="slack/send_slack_message.py"
SNOW_SCRIPT="itsm/create_servicenow_ticket.py"
JIRA_SCRIPT="itsm/create_jira_issue.py"

mkdir -p "$EVIDENCE_DIR"

echo "=================================================================="
echo " Chaos Drill: $EXPERIMENT on $SERVICE (ID: $INCIDENT_ID)"
echo "=================================================================="

# ---------------------------------------------------------------------------
# Step 1: Inject failure parameters
# ---------------------------------------------------------------------------
echo ""
echo "[STEP 1] Injecting failure scenario: $EXPERIMENT"

case "$EXPERIMENT" in
  latency)
    echo "         -> Simulating 1200ms API latency"
    LATENCY_MS=1200; ERROR_RATE=0.5; RESTARTS=0; MULTI=1
    ;;
  error_rate)
    echo "         -> Simulating 8.0% error rate"
    LATENCY_MS=200; ERROR_RATE=8.0; RESTARTS=1; MULTI=1
    ;;
  pod_kill)
    echo "         -> Simulating pod kill with 3 restarts and multi-service failures"
    LATENCY_MS=800; ERROR_RATE=3.0; RESTARTS=3; MULTI=2
    ;;
  cpu_stress)
    echo "         -> Simulating CPU saturation (950ms latency, 1.5% errors)"
    LATENCY_MS=950; ERROR_RATE=1.5; RESTARTS=1; MULTI=1
    ;;
  *)
    echo "ERROR: Unknown experiment '$EXPERIMENT'."
    echo "Valid options: latency | error_rate | pod_kill | cpu_stress"
    exit 1
    ;;
esac

# ---------------------------------------------------------------------------
# Step 2: AIOps risk scoring
# ---------------------------------------------------------------------------
echo ""
echo "[STEP 2] Running AIOps risk scoring..."
if [[ ! -f "$SCORE_SCRIPT" ]]; then
  echo "ERROR: $SCORE_SCRIPT not found. Run this script from the V9 root directory."
  exit 1
fi

bash "$SCORE_SCRIPT" \
  "$INCIDENT_ID" "$SERVICE" "$LATENCY_MS" "$ERROR_RATE" \
  "$RESTARTS" "$MULTI" "chaos-drill" "$EVIDENCE_FILE"

echo ""
echo "[STEP 2] Evidence written to: $EVIDENCE_FILE"
echo "--- Evidence ---"
cat "$EVIDENCE_FILE"
echo "----------------"

# ---------------------------------------------------------------------------
# Step 3: Slack alert
# ---------------------------------------------------------------------------
echo ""
echo "[STEP 3] Sending Slack alert..."
if command -v python3 &>/dev/null && [[ -f "$SLACK_SCRIPT" ]]; then
  if [[ -n "${SLACK_WEBHOOK_URL:-}" ]]; then
    python3 "$SLACK_SCRIPT" --evidence-file "$EVIDENCE_FILE"
  else
    echo "         SLACK_WEBHOOK_URL not set — running dry-run."
    python3 "$SLACK_SCRIPT" --dry-run --evidence-file "$EVIDENCE_FILE"
  fi
else
  echo "         Skipping: python3 or $SLACK_SCRIPT not available."
fi

# ---------------------------------------------------------------------------
# Step 4: ServiceNow ticket
# ---------------------------------------------------------------------------
echo ""
echo "[STEP 4] Creating ServiceNow incident ticket..."
if command -v python3 &>/dev/null && [[ -f "$SNOW_SCRIPT" ]]; then
  if [[ -n "${SNOW_INSTANCE:-}" ]] && [[ -n "${SNOW_USER:-}" ]] && [[ -n "${SNOW_PASSWORD:-}" ]]; then
    python3 "$SNOW_SCRIPT" --evidence-file "$EVIDENCE_FILE"
  else
    echo "         SNOW_* env vars not set — running dry-run."
    python3 "$SNOW_SCRIPT" --dry-run --evidence-file "$EVIDENCE_FILE"
  fi
else
  echo "         Skipping: python3 or $SNOW_SCRIPT not available."
fi

# ---------------------------------------------------------------------------
# Step 5: Jira issue
# ---------------------------------------------------------------------------
echo ""
echo "[STEP 5] Creating Jira issue..."
if command -v python3 &>/dev/null && [[ -f "$JIRA_SCRIPT" ]]; then
  if [[ -n "${JIRA_BASE_URL:-}" ]] && [[ -n "${JIRA_USER:-}" ]] && [[ -n "${JIRA_API_TOKEN:-}" ]]; then
    python3 "$JIRA_SCRIPT" --evidence-file "$EVIDENCE_FILE"
  else
    echo "         JIRA_* env vars not set — running dry-run."
    python3 "$JIRA_SCRIPT" --dry-run --evidence-file "$EVIDENCE_FILE"
  fi
else
  echo "         Skipping: python3 or $JIRA_SCRIPT not available."
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=================================================================="
echo " Chaos Drill Complete"
echo " Evidence : $EVIDENCE_FILE"
echo " Review the evidence, verify alerts, and document findings."
echo "=================================================================="
