#!/usr/bin/env bash
set -euo pipefail

mkdir -p artifacts/evidence

for drill in latency error_rate pod_kill cpu_stress; do
  incident_id="INC-CAPSTONE-${drill}"
  echo "Running capstone chaos drill: $drill"
  ./chaos/run_chaos_drill.sh "$incident_id" node-api "$drill" | tee "artifacts/evidence/${incident_id}.log"
done

./incident/slack_alert.sh INFO "Capstone chaos suite complete" "All four chaos drills ran. Review artifacts/evidence for results."
