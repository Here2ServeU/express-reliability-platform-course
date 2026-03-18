#!/usr/bin/env bash
set -euo pipefail

# Cloud AIOps incident test helper for V8.
# Adds guardrails and writes incident evidence for each environment.

ENVIRONMENT=${1:-dev}
SERVICE=${2:-node-api}
LATENCY_MS=${3:-700}
ERROR_RATE_PCT=${4:-2.2}
RESTART_COUNT=${5:-1}
MULTI_SERVICE_FAILURES=${6:-2}
OWNER=${7:-cloud-oncall}

if [[ "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "staging" && "$ENVIRONMENT" != "prod" ]]; then
	echo "Invalid environment '$ENVIRONMENT'. Use one of: dev staging prod"
	exit 1
fi

if [[ "$ENVIRONMENT" == "prod" && "${APPROVED_PROD_TEST:-false}" != "true" ]]; then
	echo "Prod tests require APPROVED_PROD_TEST=true"
	exit 1
fi

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
incident_id="${ENVIRONMENT}-${timestamp}"
output_file="artifacts/aiops/evidence/cloud/${incident_id}.json"

printf "AIOps cloud incident test environment: %s\n" "$ENVIRONMENT"
printf "1) Confirm approved test window and rollback owner.\n"
printf "2) Trigger one controlled incident signal in %s.\n" "$ENVIRONMENT"
printf "3) Capture AIOps risk score and incident summary.\n"
printf "4) Compare recommended action with runbook action.\n"
printf "5) Execute mitigation and track recovery time.\n"
printf "6) Verify SLO/SLI stabilization.\n"
printf "7) Promote to next environment only after stable result.\n"

./scripts/aiops_score_and_summarize.sh \
	"$incident_id" \
	"$SERVICE" \
	"$LATENCY_MS" \
	"$ERROR_RATE_PCT" \
	"$RESTART_COUNT" \
	"$MULTI_SERVICE_FAILURES" \
	"$OWNER" \
	"$output_file"

printf "Cloud AIOps incident evidence: %s\n" "$output_file"
