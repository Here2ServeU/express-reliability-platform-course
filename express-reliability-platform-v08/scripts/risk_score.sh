#!/bin/bash
###############################################################################
# risk_score.sh — a one-script introduction to AIOps-style risk scoring.
#
# Takes four incident signals and turns them into a 0-100 risk score and a
# low/medium/high verdict, using the same transparent, threshold-based rules
# a fuller AIOps pipeline would use — just without a JSON evidence file, a
# Slack integration, or a rules file to keep in sync. Read the four `if`
# blocks below: that's the entire model.
#
# Usage:
#   ./scripts/risk_score.sh [latency_ms] [error_rate_pct] [restart_count] [multi_service_failures]
#
# All four arguments are optional and default to a healthy baseline, so
# `./scripts/risk_score.sh` alone runs and scores 0/low.
###############################################################################
set -euo pipefail

LATENCY_MS="${1:-120}"
ERROR_RATE_PCT="${2:-0.2}"
RESTART_COUNT="${3:-0}"
MULTI_SERVICE_FAILURES="${4:-0}"

SCORE=0

# ─── Signal 1: Latency ──────────────────────────────────────────
if awk -v v="${LATENCY_MS}" 'BEGIN { exit !(v > 500) }'; then
  SCORE_LATENCY=30
else
  SCORE_LATENCY=0
fi
SCORE=$((SCORE + SCORE_LATENCY))

# ─── Signal 2: Error rate ───────────────────────────────────────
if awk -v v="${ERROR_RATE_PCT}" 'BEGIN { exit !(v > 1.0) }'; then
  SCORE_ERROR=30
else
  SCORE_ERROR=0
fi
SCORE=$((SCORE + SCORE_ERROR))

# ─── Signal 3: Restarts ─────────────────────────────────────────
if awk -v v="${RESTART_COUNT}" 'BEGIN { exit !(v > 0) }'; then
  SCORE_RESTART=20
else
  SCORE_RESTART=0
fi
SCORE=$((SCORE + SCORE_RESTART))

# ─── Signal 4: Blast radius ─────────────────────────────────────
if awk -v v="${MULTI_SERVICE_FAILURES}" 'BEGIN { exit !(v > 1) }'; then
  SCORE_BLAST=20
else
  SCORE_BLAST=0
fi
SCORE=$((SCORE + SCORE_BLAST))

echo "=== AIOps Risk Score (intro) ==="
echo "Latency:      ${LATENCY_MS}ms          → ${SCORE_LATENCY} pts"
echo "Error rate:   ${ERROR_RATE_PCT}%        → ${SCORE_ERROR} pts"
echo "Restarts:     ${RESTART_COUNT}              → ${SCORE_RESTART} pts"
echo "Blast radius: ${MULTI_SERVICE_FAILURES} services failing → ${SCORE_BLAST} pts"
echo "──────────────────────────────────────"
echo "TOTAL RISK SCORE: ${SCORE} / 100"

if [ "${SCORE}" -ge 70 ]; then
  echo "VERDICT: HIGH — declare an incident, start mitigation now."
elif [ "${SCORE}" -ge 40 ]; then
  echo "VERDICT: MEDIUM — open a ticket, assign an owner."
else
  echo "VERDICT: LOW — keep watching dashboards."
fi
