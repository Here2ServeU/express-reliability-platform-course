#!/usr/bin/env bash
set -euo pipefail

# Build a simple AIOps incident summary and risk score.
# Usage:
# ./scripts/aiops_score_and_summarize.sh <incident_id> <service> <latency_ms> <error_rate_pct> <restart_count> <multi_service_failures> <owner> <output_file>

if [[ "$#" -ne 8 ]]; then
  echo "Usage: $0 <incident_id> <service> <latency_ms> <error_rate_pct> <restart_count> <multi_service_failures> <owner> <output_file>"
  exit 1
fi

incident_id="$1"
service="$2"
latency_ms="$3"
error_rate_pct="$4"
restart_count="$5"
multi_service_failures="$6"
owner="$7"
output_file="$8"

risk_score=0

if awk "BEGIN {exit !($error_rate_pct > 1.0)}"; then
  risk_score=$((risk_score + 30))
fi

if awk "BEGIN {exit !($latency_ms > 500)}"; then
  risk_score=$((risk_score + 30))
fi

if [[ "$restart_count" -gt 0 ]]; then
  risk_score=$((risk_score + 20))
fi

if [[ "$multi_service_failures" -gt 1 ]]; then
  risk_score=$((risk_score + 20))
fi

severity="low"
recommended_action="Investigate dashboards and watch trends for 10 minutes."

if [[ "$risk_score" -ge 70 ]]; then
  severity="high"
  recommended_action="Declare incident, start mitigation immediately, and trigger on-call escalation."
elif [[ "$risk_score" -ge 40 ]]; then
  severity="medium"
  recommended_action="Open incident ticket, assign owner, and apply first runbook mitigation step."
fi

mkdir -p "$(dirname "$output_file")"

cat > "$output_file" <<EOF
{
  "incident_id": "$incident_id",
  "service": "$service",
  "latency_ms": $latency_ms,
  "error_rate_pct": $error_rate_pct,
  "restart_count": $restart_count,
  "multi_service_failures": $multi_service_failures,
  "risk_score": $risk_score,
  "severity": "$severity",
  "recommended_action": "$recommended_action",
  "owner": "$owner",
  "generated_at_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

echo "AIOps summary written to $output_file"
echo "risk_score=$risk_score severity=$severity"