#!/usr/bin/env bash
#
# Resolve an incident by running one script.
#
# This is the command named in every Slack alert. An on-call engineer copies it
# from the alert and runs it to drive the recommended remediation for the signal.
#
# Usage:
#   ./remediation/resolve_incident.sh <signal> [service]
#
#   <signal>  one of: latency | error_rate | cpu | pod_kill
#   [service] target service name (default: node-api)
#
# Dry run (print actions without touching anything):
#   DRY_RUN=1 ./remediation/resolve_incident.sh latency node-api
#
# GitOps note: where a fix is a rollback, the safe action under ArgoCD is to
# revert the Git change (or `argocd app rollback`) so the platform self-heals to
# the previous good revision instead of mutating the cluster by hand.

set -euo pipefail

SIGNAL="${1:-}"
SERVICE="${2:-node-api}"
DRY_RUN="${DRY_RUN:-0}"
NAMESPACE="${NAMESPACE:-express-platform}"

if [[ -z "$SIGNAL" ]]; then
  echo "Usage: $0 <latency|error_rate|cpu|pod_kill> [service]" >&2
  exit 2
fi

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "  [dry-run] $*"
  else
    echo "  + $*"
    eval "$@"
  fi
}

echo "Resolving '$SIGNAL' on service '$SERVICE' (namespace: $NAMESPACE)"
echo "------------------------------------------------------------"

case "$SIGNAL" in
  latency)
    echo "Plan: restart workload, shed load, verify p95 recovers."
    run "kubectl rollout restart deployment/$SERVICE -n $NAMESPACE"
    run "kubectl rollout status deployment/$SERVICE -n $NAMESPACE --timeout=120s"
    ;;
  error_rate)
    echo "Plan: roll back to the last healthy revision via GitOps."
    run "argocd app rollback $SERVICE"
    run "kubectl rollout status deployment/$SERVICE -n $NAMESPACE --timeout=120s"
    ;;
  cpu)
    echo "Plan: scale out to absorb CPU saturation, then re-evaluate."
    run "kubectl scale deployment/$SERVICE -n $NAMESPACE --replicas=4"
    run "kubectl get hpa -n $NAMESPACE"
    ;;
  pod_kill)
    echo "Plan: restart the workload and confirm readiness probe recovers."
    run "kubectl rollout restart deployment/$SERVICE -n $NAMESPACE"
    run "kubectl wait --for=condition=available deployment/$SERVICE -n $NAMESPACE --timeout=120s"
    ;;
  *)
    echo "Unknown signal '$SIGNAL'. Use latency | error_rate | cpu | pod_kill." >&2
    exit 2
    ;;
esac

echo "------------------------------------------------------------"
echo "Remediation steps issued for '$SIGNAL' on '$SERVICE'."
echo "Verify recovery in Grafana, then record the outcome in the incident runbook."
