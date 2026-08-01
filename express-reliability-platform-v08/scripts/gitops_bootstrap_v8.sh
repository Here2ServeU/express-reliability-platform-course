#!/bin/bash
###############################################################################
# gitops_bootstrap_v8.sh — install Argo CD and hand it the keys.
#
# This is the one imperative step in V8's deploy path. Everything it does is
# "install the thing that will do everything else from Git":
#
#   1. Argo CD itself (Helm, gitops/argocd/values.yaml)
#   2. the `platform` AppProject   — what Argo CD is ALLOWED to deploy
#   3. the root Application        — what Argo CD SHOULD deploy
#
# After step 3, `helm upgrade --install` never appears in the app deploy path
# again. Changing what runs in the cluster means committing to Git.
#
# Usage:
#   ENV=dev ./scripts/gitops_bootstrap_v8.sh     # default
#   ENV=prod ./scripts/gitops_bootstrap_v8.sh
#
# Assumes: a working kubectl context, and that the argocd namespace already
# exists with its governance labels (tf_deploy_v8.sh applies
# governance/namespaces/ before calling this).
###############################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

ENV="${ENV:-dev}"
case "${ENV}" in
  dev|staging|prod) ;;
  *) echo "ERROR: ENV must be one of dev|staging|prod (got: ${ENV})" >&2; exit 1 ;;
esac

# staging has no gitops/apps/staging directory in the course; it would be a
# copy of dev with its own replica counts. Fail loudly rather than syncing
# the wrong environment's manifests.
ROOT_APP="gitops/argocd/root-app-${ENV}.yaml"
if [[ ! -f "${ROOT_APP}" ]]; then
  echo "ERROR: ${ROOT_APP} not found." >&2
  echo "       Copy gitops/apps/dev to gitops/apps/${ENV} and add a matching" >&2
  echo "       root-app-${ENV}.yaml if you want a ${ENV} environment." >&2
  exit 1
fi

# ── Guard: refuse to bootstrap against placeholder manifests ─────────────────
# Argo CD would accept these and then sit in "Unknown" state forever with a
# repo-not-found error buried in the UI. Better to say so now.
if grep -rq 'YOUR_GITHUB_USERNAME' gitops/; then
  echo "ERROR: gitops/ still contains the placeholder repo URL." >&2
  echo >&2
  echo "  Run:  ./scripts/gitops_set_repo_v8.sh" >&2
  echo "  Then: commit and push the result — Argo CD reads your pushed" >&2
  echo "        commit, not your working copy." >&2
  exit 1
fi

echo "=== Step 1: Install Argo CD (Helm) ==="
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update argo >/dev/null 2>&1 || true
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  -f gitops/argocd/values.yaml \
  --wait --timeout 10m

echo '=== Step 2: Wait for the Application CRD to be established ==='
# The AppProject and Application applied below are custom resources. Helm
# --wait waits for Argo CD's pods, not for the API server to finish
# registering its CRDs, so applying immediately can fail with
# "no matches for kind Application".
kubectl wait --for=condition=Established --timeout=120s \
  crd/applications.argoproj.io crd/appprojects.argoproj.io

echo '=== Step 3: Apply the platform AppProject (the guardrails) ==='
kubectl apply -f gitops/argocd/project.yaml

echo "=== Step 4: Apply the ${ENV} root Application (the app-of-apps) ==="
kubectl apply -f "${ROOT_APP}"

echo '=== Step 5: Argo CD admin password ==='
# The chart generates this on first install and stores it in a Secret. It is
# not rotated by re-running this script.
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null || echo '')

echo
echo '=== Argo CD is installed and syncing. ==='
echo
echo '  kubectl port-forward -n argocd svc/argocd-server 8081:80'
echo '  open http://localhost:8081'
echo '    user: admin'
if [[ -n "${ARGOCD_PASSWORD}" ]]; then
  echo "    pass: ${ARGOCD_PASSWORD}"
else
  echo '    pass: kubectl -n argocd get secret argocd-initial-admin-secret \'
  echo '            -o jsonpath="{.data.password}" | base64 -d'
fi
echo
echo 'Watch the first sync land:'
echo '  kubectl get applications -n argocd -w'
echo
echo 'Expect root-'"${ENV}"' plus flask-api, node-api, and web-ui to reach'
echo 'Synced/Healthy. If they sit in Unknown, the repo URL or branch in'
echo 'gitops/ does not match a commit you have actually pushed.'
