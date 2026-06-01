#!/usr/bin/env bash
#
# Capstone deploy-all: bring up the standalone platform end to end.
#
# The capstone is a self-contained project: it owns the application services,
# the AIOps intelligence layer, GitOps (ArgoCD), observability + alerting, and
# FinOps. This script walks the platform in dependency order and stops on the
# first failure.
#
# Usage:
#   ./scripts/deploy_all.sh            # guided run
#   DRY_RUN=1 ./scripts/deploy_all.sh  # print the plan only, change nothing
#
# Run it from the capstone root.

set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

step() {
  local title="$1" cmd="$2"
  echo
  echo "=============================================================="
  echo "$title"
  echo "  cmd: $cmd"
  echo "=============================================================="
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "  [dry-run] skipped"
    return 0
  fi
  eval "$cmd"
}

echo "Capstone deploy-all: root: $ROOT"

# --- 1) Application services (local build) --------------------------------
step "Build application images (node-api, flask-api, web-ui)" \
  "for s in node-api flask-api web-ui; do docker build -t erp-capstone-\$s ./apps/\$s; done"

# --- 2) Observability + alerting ------------------------------------------
step "Bring up observability (Prometheus + Alertmanager + Grafana)" \
  "docker compose -f docker-compose.observability.yml up -d"

step "Start the Alertmanager -> Slack bridge (background)" \
  "python3 alerting/alertmanager_webhook.py &"

# --- 3) Intelligence loop (AIOps) -----------------------------------------
step "Run the AIOps intelligence loop (detect -> score -> alert)" \
  "chmod +x scripts/run_intelligence_loop.sh remediation/resolve_incident.sh && ./scripts/run_intelligence_loop.sh latency node-api"

# --- 4) FinOps ------------------------------------------------------------
step "FinOps cost report (requires AWS credentials)" \
  "echo 'Run when AWS is configured: python3 finops/check_costs.py'"

# --- 5) GitOps delivery (ArgoCD) ------------------------------------------
step "GitOps: apply ArgoCD project + ApplicationSet" \
  "echo 'On a cluster: kubectl apply -f infrastructure/argocd/project.yaml && kubectl apply -f infrastructure/argocd/applicationsets/platform-services.yaml'"

echo
echo "Capstone platform walk complete."
echo "Finish the artifacts/ templates and present with docs/interview-and-client-playbook.md."
