#!/usr/bin/env bash
set -euo pipefail

# Cloud chaos test checklist runner (safe helper).
# This script does not force faults by itself; it guides controlled execution.

ENVIRONMENT=${1:-dev}

printf "Cloud chaos test environment: %s\n" "$ENVIRONMENT"
printf "1) Confirm change window is open.\n"
printf "2) Confirm rollback owner is assigned.\n"
printf "3) Start low-risk experiment (single task/pod fault) in %s.\n" "$ENVIRONMENT"
printf "4) Watch SLO/SLI metrics and alerts for 15 minutes.\n"
printf "5) Capture evidence: latency, errors, recovery time.\n"
printf "6) Roll back fault and verify steady state.\n"
printf "7) If environment is dev and result is stable, repeat in staging, then prod with approval.\n"
