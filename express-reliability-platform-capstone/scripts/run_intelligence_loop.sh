#!/usr/bin/env bash
#
# End-to-end Intelligence loop in one command:
#   simulate -> detect -> score/summarize -> Slack alert (naming the resolve script)
#
# Usage:
#   ./scripts/run_intelligence_loop.sh <signal> [service]
#     <signal>  latency | error_rate | cpu | pod_kill
#     [service] default: node-api
#
# Slack send is automatic when SLACK_WEBHOOK_URL is set, otherwise it dry-runs.

set -euo pipefail

SIGNAL="${1:-latency}"
SERVICE="${2:-node-api}"
INCIDENT="INC-$(echo "$SIGNAL" | tr '[:lower:]' '[:upper:]')"
EVIDENCE="artifacts/evidence/${INCIDENT}.json"

echo "==> 1/3 Detect"
case "$SIGNAL" in
  latency)    python3 aiops/detect_anomaly.py --signal latency --value 1200 ;;
  error_rate) python3 aiops/detect_anomaly.py --signal error_rate --value 0.08 ;;
  cpu)        python3 aiops/detect_anomaly.py --signal cpu --value 0.92 ;;
  pod_kill)   python3 aiops/detect_anomaly.py --signal pod_kill --value 1 ;;
  *) echo "Unknown signal '$SIGNAL'"; exit 2 ;;
esac

echo "==> 2/3 Score + summarize"
python3 aiops/score_and_summarize.py --signal "$SIGNAL" --service "$SERVICE" --incident-id "$INCIDENT"

echo "==> 3/3 Alert (Slack)"
python3 alerting/send_slack_alert.py --evidence-file "$EVIDENCE"

echo
echo "Resolve the incident with the command named in the alert above:"
echo "  ./remediation/resolve_incident.sh $SIGNAL $SERVICE"
