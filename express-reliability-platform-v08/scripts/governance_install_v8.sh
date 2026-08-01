#!/bin/bash
###############################################################################
# governance_install_v8.sh — install OPA Gatekeeper and enforce V8's policies.
#
# Gatekeeper is a validating admission webhook: it sits in front of the API
# server and can reject an object before it is ever written to etcd. That
# makes it the enforcement half of governance. The other half — Trivy and
# Checkov in .github/workflows/provision.yml — runs earlier, in CI, and can
# only fail a build. Gatekeeper is what stops someone bypassing CI with
# `kubectl apply` from their laptop.
#
# Three policies ship in governance/gatekeeper/:
#   no-latest-tag           — Pods in `platform` may not use :latest, or no tag
#   require-resource-limits — Pods in `platform` must set cpu + memory limits
#   require-ns-labels       — every Namespace must carry owner + environment
#
# Usage:
#   ./scripts/governance_install_v8.sh
#   ENFORCEMENT=dryrun ./scripts/governance_install_v8.sh   # audit, don't block
#
# ENFORCEMENT=dryrun flips all three constraints to report-only. Use it when
# introducing these policies to a cluster that already has running workloads:
# `kubectl get constraints` then shows you every existing violation without
# breaking a single deploy. Switch to deny once the list is empty.
###############################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

GATEKEEPER_VERSION="${GATEKEEPER_VERSION:-3.23.0}"
ENFORCEMENT="${ENFORCEMENT:-deny}"

echo "=== Step 1: Install Gatekeeper ${GATEKEEPER_VERSION} (Helm) ==="
# The Helm chart rather than the raw deploy.yaml URL: it gives a clean
# `helm uninstall` for teardown, and pins a chart version instead of tracking
# whatever a branch happens to point at today.
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts >/dev/null 2>&1 || true
helm repo update gatekeeper >/dev/null 2>&1 || true
helm upgrade --install gatekeeper gatekeeper/gatekeeper \
  --namespace gatekeeper-system --create-namespace \
  --version "${GATEKEEPER_VERSION}" \
  --set replicas=1 \
  --set auditInterval=60 \
  --wait --timeout 10m

echo '=== Step 2: Apply ConstraintTemplates ==='
# A ConstraintTemplate is a Rego policy plus a CRD definition. Applying one
# makes Gatekeeper register a brand-new custom resource kind (NoLatestTag,
# RequireResourceLimits, RequireNsLabels) with the API server.
kubectl apply -f governance/gatekeeper/templates/

echo '=== Step 3: Wait for the generated CRDs to be established ==='
# This wait is the step everyone skips and then debugs for twenty minutes.
# `kubectl apply` on a ConstraintTemplate returns as soon as the template is
# stored — Gatekeeper still has to compile the Rego and ask the API server to
# register the CRD. Apply the constraints in that window and you get:
#
#   error: no matches for kind "NoLatestTag" in version
#          "constraints.gatekeeper.sh/v1beta1"
#
# which reads like a typo in the manifest and is actually just impatience.
for CRD in nolatesttag requireresourcelimits requirenslabels; do
  echo "  waiting for ${CRD}.constraints.gatekeeper.sh ..."
  kubectl wait --for=condition=Established --timeout=120s \
    "crd/${CRD}.constraints.gatekeeper.sh"
done

# Gatekeeper also needs its webhook to be serving before a constraint can be
# enforced. The pods are Ready (helm --wait), but the webhook's TLS cert is
# distributed by a separate controller a moment later.
echo '=== Step 4: Wait for the admission webhook to serve ==='
kubectl wait --for=condition=Available --timeout=180s \
  deployment/gatekeeper-controller-manager -n gatekeeper-system
kubectl wait --for=condition=Available --timeout=180s \
  deployment/gatekeeper-audit -n gatekeeper-system

echo "=== Step 5: Apply Constraints (enforcementAction: ${ENFORCEMENT}) ==="
if [[ "${ENFORCEMENT}" == "deny" ]]; then
  kubectl apply -f governance/gatekeeper/constraints/
else
  # Rewrite the enforcementAction on the way in, leaving the committed
  # manifests untouched. `kubectl apply -f -` reads the patched stream.
  for F in governance/gatekeeper/constraints/*.yaml; do
    sed "s/^  enforcementAction: .*/  enforcementAction: ${ENFORCEMENT}/" "${F}" \
      | kubectl apply -f -
  done
  echo
  echo "  NOTE: constraints are in '${ENFORCEMENT}' mode — violations are"
  echo "        recorded but nothing is blocked. Inspect them with:"
  echo "          kubectl get constraints"
fi

echo
echo '=== Governance is enforcing. ==='
echo
kubectl get constraints 2>/dev/null || true
echo
echo 'Prove it rejects something (expect all three to be denied):'
echo
echo '  # 1. a :latest image'
echo '  kubectl run bad-tag --image=nginx:latest -n platform'
echo
echo '  # 2. a pod with no resource limits'
echo '  kubectl run bad-limits --image=nginx:1.27 -n platform'
echo
echo '  # 3. a namespace with no owner/environment labels'
echo '  kubectl create namespace rogue'
