#!/usr/bin/env bash
set -euo pipefail

# Local AIOps incident test helper for V8.
# Generates a local incident risk score and summary evidence file.

API_URL=${1:-http://localhost:8080/api/health}
SERVICE=${2:-node-api}
LATENCY_MS=${3:-650}
ERROR_RATE_PCT=${4:-1.8}
RESTART_COUNT=${5:-1}
MULTI_SERVICE_FAILURES=${6:-1}
OWNER=${7:-local-oncall}

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
incident_id="local-${timestamp}"
output_file="artifacts/aiops/evidence/local/${incident_id}.json"

printf "Step 1: verify local stack health at %s\n" "$API_URL"
curl -fsS "$API_URL" > /dev/null

printf "Step 2: prepare incident signal values for scoring.\n"
printf "- service=%s latency_ms=%s error_rate_pct=%s restarts=%s multi_service_failures=%s\n" \
	"$SERVICE" "$LATENCY_MS" "$ERROR_RATE_PCT" "$RESTART_COUNT" "$MULTI_SERVICE_FAILURES"

printf "Step 3: score and summarize incident.\n"
./scripts/aiops_score_and_summarize.sh \
	"$incident_id" \
	"$SERVICE" \
	"$LATENCY_MS" \
	"$ERROR_RATE_PCT" \
	"$RESTART_COUNT" \
	"$MULTI_SERVICE_FAILURES" \
	"$OWNER" \
	"$output_file"

printf "Step 4: validate recovery criteria.\n"
printf "- Confirm health endpoint remains available.\n"
printf "- Confirm SLO/SLI trends return to baseline.\n"

printf "Local AIOps incident test completed. Evidence: %s\n" "$output_file"
