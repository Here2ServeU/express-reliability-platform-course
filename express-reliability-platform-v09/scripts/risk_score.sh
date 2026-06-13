#!/bin/bash
set -e

# ─── Signal 1: Change Size ─────────────────────────────────────
# How many files changed in the last commit?
CHANGED=$(git diff --name-only HEAD~1 HEAD 2>/dev/null | wc -l | tr -d ' ')

if [ "$CHANGED" -ge 50 ]; then SCORE_SIZE=30
elif [ "$CHANGED" -ge 20 ]; then SCORE_SIZE=20
elif [ "$CHANGED" -ge 5 ]; then SCORE_SIZE=10
else SCORE_SIZE=2
fi

# ─── Signal 2: Scan Findings ───────────────────────────────────
# Count MEDIUM CVEs from the most recent Trivy scan
# (HIGH/CRITICAL are already blocked by the scan job)
MEDIUM_CVES=${TRIVY_MEDIUM_COUNT:-0}

if [ "$MEDIUM_CVES" -ge 10 ]; then SCORE_SCAN=25
elif [ "$MEDIUM_CVES" -ge 5 ]; then SCORE_SCAN=15
elif [ "$MEDIUM_CVES" -ge 1 ]; then SCORE_SCAN=8
else SCORE_SCAN=0
fi

# ─── Signal 3: Error Rate ──────────────────────────────────────
# Query the flask-api /metrics endpoint for 5xx rate
# If /metrics is unreachable, treat as low risk (service may be starting)
ERROR_RATE=0
if PUBLIC=$(kubectl get svc web-ui-web-ui -n platform \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null); then
  ERROR_RATE=$(curl -s --max-time 5 \
    "http://${PUBLIC}/metrics" 2>/dev/null | \
    grep 'flask_api_requests_total.*status="5' | \
    awk '{print $2}' | head -1 || echo '0')
fi

if (( $(echo "$ERROR_RATE > 10" | bc -l) )); then SCORE_ERROR=25
elif (( $(echo "$ERROR_RATE > 5" | bc -l) )); then SCORE_ERROR=15
elif (( $(echo "$ERROR_RATE > 1" | bc -l) )); then SCORE_ERROR=8
else SCORE_ERROR=0
fi

# ─── Signal 4: Time of Day ─────────────────────────────────────
# Is this a risky deploy window? (Friday after 3pm, weekends)
HOUR=$(date +%H)
DOW=$(date +%u)   # 1=Monday … 7=Sunday

SCORE_TIME=0
# Friday after 15:00
if [ "$DOW" -eq 5 ] && [ "$HOUR" -ge 15 ]; then SCORE_TIME=15
# Saturday or Sunday
elif [ "$DOW" -ge 6 ]; then SCORE_TIME=15
# Any day after 20:00 or before 07:00
elif [ "$HOUR" -ge 20 ] || [ "$HOUR" -lt 7 ]; then SCORE_TIME=10
fi

# ─── Signal 5: Rollback Recency ────────────────────────────────
# Was the last deploy rolled back within the last 24 hours?
SCORE_ROLLBACK=0
LAST_ROLLBACK=${LAST_ROLLBACK_HOURS:-999}
if [ "$LAST_ROLLBACK" -lt 24 ]; then SCORE_ROLLBACK=5; fi

# ─── Final Score ───────────────────────────────────────────────
TOTAL=$((SCORE_SIZE + SCORE_SCAN + SCORE_ERROR + SCORE_TIME + SCORE_ROLLBACK))

echo "=== AIOps Risk Score ==="
echo "Change size: ${CHANGED} files → ${SCORE_SIZE} pts"
echo "Scan findings: ${MEDIUM_CVES} MEDIUM CVEs → ${SCORE_SCAN} pts"
echo "Error rate: ${ERROR_RATE}% → ${SCORE_ERROR} pts"
echo "Deploy window: $(date '+%A %H:%M') → ${SCORE_TIME} pts"
echo "Rollback recency: ${LAST_ROLLBACK} hrs ago → ${SCORE_ROLLBACK} pts"
echo "────────────────────────────────────"
echo "TOTAL RISK SCORE: ${TOTAL} / 100"

# ─── Go / No-Go Decision ───────────────────────────────────────
if [ "$TOTAL" -le 29 ]; then
  echo "VERDICT: LOW — Deploy proceeds automatically."
  exit 0
elif [ "$TOTAL" -le 59 ]; then
  echo "VERDICT: MEDIUM — Deploy proceeds. Warning posted to Slack."
  exit 0
elif [ "$TOTAL" -le 79 ]; then
  echo "VERDICT: HIGH — Deploy PAUSED. Engineer approval required."
  exit 1   # Fail the pipeline step — engineer must re-trigger manually
else
  echo "VERDICT: CRITICAL — Deploy BLOCKED. Incident opened. On-call paged."
  exit 1
fi
