#!/bin/bash
NAMESPACE=${NAMESPACE:-"platform"}
SLACK_WEBHOOK_URL=${SLACK_WEBHOOK_URL:-"YOUR_SLACK_WEBHOOK_URL"}
RECOVERY_SLO=${RECOVERY_SLO:-60}

PASS=0; FAIL=0; RESULTS=""

run_drill() {
  local NAME=$1 SCRIPT=$2
  local START=$(date +%s)
  echo ""
  echo "=== $NAME ==="
  if NAMESPACE=$NAMESPACE bash "$SCRIPT"; then
    local END=$(date +%s)
    local ELAPSED=$((END - START))
    if [ "$ELAPSED" -le "$RECOVERY_SLO" ]; then
      RESULTS="$RESULTS✓ $NAME: PASSED in ${ELAPSED}s (SLO: ${RECOVERY_SLO}s)"
      PASS=$((PASS + 1))
    else
      RESULTS="$RESULTS⚠ $NAME: SLO BREACH — ${ELAPSED}s (SLO: ${RECOVERY_SLO}s)"
      FAIL=$((FAIL + 1))
    fi
  else
    RESULTS="$RESULTS✗ $NAME: FAILED"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Chaos Suite: starting all four drills ==="
echo "Namespace: $NAMESPACE  SLO: ${RECOVERY_SLO}s"

run_drill "Drill 1: Pod Kill" "chaos/kill_pod.sh"
run_drill "Drill 2: Node Drain" "chaos/node_drain.sh"
run_drill "Drill 3: CPU Pressure" "chaos/resource_pressure.sh"
run_drill "Drill 4: Crash Loop" "chaos/kill_pod.sh --crash-loop"

echo ""
echo "=== Chaos Suite Complete ==="
echo -e "Results:$RESULTS"
echo "Passed: $PASS  Failed/SLO Breach: $FAIL"

# Post summary to Slack
bash incident/slack_alert.sh INFO "Chaos Suite Complete" \
  "Passed: $PASS  Failed: $FAIL | $RESULTS"
