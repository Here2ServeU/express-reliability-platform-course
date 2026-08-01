#!/bin/bash
###############################################################################
# Deploy V8 against a specific environment (dev, staging, or prod).
#
# Usage:
#   ENV=dev  ./scripts/tf_deploy_v8.sh   # default if ENV unset
#   ENV=prod ./scripts/tf_deploy_v8.sh
#
# Per-env behavior:
#   - tfvars file:   platform/terraform/eks/environments/<env>.tfvars
#   - state key:     eks/v8/<env>/terraform.tfstate  (env-scoped: dev and
#                    prod never share state or fight over the lock)
#   - cluster name:  reliability-platform-<env>      (set by root locals)
#
# WHAT CHANGED FROM V7
#
# V7's steps 1-6 and its monitoring install are here unchanged. Two things
# are different, and they are the whole of V8:
#
#   Governance (new step 7) — OPA Gatekeeper and three policies go in BEFORE
#   any workload does. Order matters: the policies deny unlabelled
#   namespaces, so the namespaces have to be declared first, and they deny
#   :latest images, so V7's `--set image.tag=latest` path would now be
#   rejected at admission.
#
#   GitOps (replaces V7's step 7) — the `helm upgrade --install` loop over
#   the three app charts is GONE. Argo CD installs instead, reads
#   gitops/apps/<env>/ from your Git repo, and deploys from there. This
#   script stops being the thing that deploys your apps; it becomes the
#   thing that installs the thing that deploys your apps, and then gets out
#   of the way.
#
# Set SKIP_GITOPS=true to stand up the cluster + governance + monitoring
# without Argo CD (useful if you have not pushed your gitops/ changes yet).
###############################################################################
set -euo pipefail

ENV="${ENV:-dev}"
case "${ENV}" in
  dev|staging|prod) ;;
  *) echo "ERROR: ENV must be one of dev|staging|prod (got: ${ENV})" >&2; exit 1 ;;
esac

TFVARS_FILE="platform/terraform/eks/environments/${ENV}.tfvars"
if [[ ! -f "${TFVARS_FILE}" ]]; then
  echo "ERROR: ${TFVARS_FILE} not found." >&2
  exit 1
fi

REGION="us-east-1"
PROJECT="reliability-platform"
NAMESPACE="platform"
SERVICES=(flask-api node-api web-ui)

echo "=== Target environment: ${ENV} (tfvars: ${TFVARS_FILE}) ==="

echo '=== Step 1: Apply V8 bootstrap (state bucket, lock table, ECR repos) ==='
# V8 owns its full bootstrap: state backend AND the three ECR repos. V7 stays
# untouched. See platform/terraform/bootstrap/{main,ecr}.tf.
terraform -chdir=platform/terraform/bootstrap init -input=false
terraform -chdir=platform/terraform/bootstrap apply -auto-approve

echo '=== Step 2: Read bootstrap outputs ==='
STATE_BUCKET=$(terraform -chdir=platform/terraform/bootstrap output -raw state_bucket)
LOCK_TABLE=$(terraform -chdir=platform/terraform/bootstrap output -raw lock_table)
ECR_BASE=$(terraform -chdir=platform/terraform/bootstrap output -raw ecr_base_uri)

echo "  state bucket: ${STATE_BUCKET}"
echo "  lock table:   ${LOCK_TABLE}"
echo "  ECR base:     ${ECR_BASE}"

echo '=== Step 2b: Build and push images (from this repos apps/) ==='
"${0%/*}/build_push_images_v8.sh"

echo "=== Step 3: Initialize EKS stack against V8 bootstrap backend (${ENV}) ==="
# State key is per-env so dev and prod live in separate state files in the
# same bucket. -reconfigure tolerates switching between envs in the same
# clone (different state key each time).
terraform -chdir=platform/terraform/eks init \
  -reconfigure -input=false \
  -backend-config="bucket=${STATE_BUCKET}" \
  -backend-config="region=${REGION}" \
  -backend-config="dynamodb_table=${LOCK_TABLE}" \
  -backend-config="key=eks/v8/${ENV}/terraform.tfstate"

echo "=== Step 4: Apply EKS Terraform for ${ENV} (10-15 minutes) ==="
terraform -chdir=platform/terraform/eks apply -auto-approve \
  -var-file="environments/${ENV}.tfvars"

echo '=== Step 5: Configure kubectl for the new cluster ==='
CLUSTER=$(terraform -chdir=platform/terraform/eks output -raw cluster_name)
aws eks --region "${REGION}" update-kubeconfig --name "${CLUSTER}"
kubectl get nodes

echo '=== Step 6: Create the three namespaces, labelled ==='
# CHANGED FROM V7, and this is the ordering constraint that governance
# imposes on everything after it.
#
# V7 ran `kubectl create namespace platform` here and let Helm create
# `monitoring` implicitly with --create-namespace. Neither produces labels.
# V8's require-ns-labels constraint denies a Namespace without `owner` and
# `environment`, so both of those calls would fail at admission — but only
# AFTER Gatekeeper is installed in step 7. Declaring all three namespaces
# here, from governance/namespaces/, means they already exist and already
# comply by the time the policy starts enforcing.
kubectl apply -f governance/namespaces/

# The committed manifests carry `environment: dev`. Re-label to the env
# actually being deployed. The constraint only requires the label to be
# present, but a prod namespace labelled `dev` is a lie that someone will
# eventually act on.
for NS in platform monitoring argocd; do
  kubectl label namespace "${NS}" "environment=${ENV}" --overwrite >/dev/null
done
kubectl get namespaces platform monitoring argocd --show-labels

echo '=== Step 7: Install governance (Gatekeeper + three policies) ==='
# NEW IN V8. Runs before any workload is deployed, so the policies are
# enforcing for the very first pod rather than being retrofitted onto a
# running cluster. Set SKIP_GOVERNANCE=true to stand up the cluster without
# it; set ENFORCEMENT=dryrun to install the policies in audit-only mode.
if [ "${SKIP_GOVERNANCE:-false}" != "true" ]; then
  "${0%/*}/governance_install_v8.sh"
else
  echo '  SKIP_GOVERNANCE=true — skipping.'
fi

echo '=== Step 8: Install monitoring stack (Prometheus/Grafana/Alertmanager) ==='
# Carried over from V7 unchanged, except that the `monitoring` namespace was
# already created (labelled) in step 6 instead of by --create-namespace.
# Uses the community kube-prometheus-stack chart with this project's values
# (platform/helm/global-monitoring/values.yaml) — same alert rules as the
# local docker-compose stack, deployed cluster-wide. Set SKIP_MONITORING=true
# to skip this step.
if [ "${SKIP_MONITORING:-false}" != "true" ]; then
  # grafana-dashboards must exist before the kube-prometheus-stack install:
  # values.yaml sets dashboardsConfigMaps.default to this name, and the
  # Grafana pod's volume mount hangs in ContainerCreating waiting for it if
  # it's not there yet.
  helm upgrade --install grafana-dashboards platform/helm/grafana-dashboards \
    --namespace monitoring

  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
  helm repo update prometheus-community >/dev/null 2>&1 || true
  helm upgrade --install global-monitoring prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    -f platform/helm/global-monitoring/values.yaml
else
  echo '  SKIP_MONITORING=true — skipping.'
fi

echo '=== Step 9: Hand the apps over to GitOps (Argo CD) ==='
# REPLACES V7's step 7. There is no `helm upgrade --install` for flask-api,
# node-api, or web-ui in this script any more, and no `rollout restart`
# either — that hack existed only because V7 deployed a mutable `:latest`
# tag, and V8 does not.
#
# From here, the three services are deployed by Argo CD from whatever is
# committed in gitops/apps/${ENV}/ in your Git repo. If you have not run
# gitops_set_repo_v8.sh and pushed the result yet, this step stops with
# instructions rather than installing something that cannot sync.
if [ "${SKIP_GITOPS:-false}" != "true" ]; then
  ENV="${ENV}" "${0%/*}/gitops_bootstrap_v8.sh"
else
  echo '  SKIP_GITOPS=true — skipping. The cluster has no applications yet.'
  echo '  Deploy them the V7 way (bypasses GitOps entirely) with:'
  for SVC in "${SERVICES[@]}"; do
    echo "    helm upgrade --install ${SVC} platform/helm/${SVC} -n ${NAMESPACE} \\"
    echo "      --set image.repository=${ECR_BASE}/${SVC} --set image.tag=v8"
  done
fi

echo '=== Step 10: Wait for Argo CD to sync the apps ==='
# Argo CD clones the repo, renders the charts, and applies them. On a cold
# cluster that is typically under two minutes; the ALB behind web-ui takes
# another 60-90s after that.
if [ "${SKIP_GITOPS:-false}" != "true" ]; then
  echo '  waiting for the three Deployments to appear...'
  for i in $(seq 1 30); do
    FOUND=$(kubectl get deploy -n "${NAMESPACE}" --no-headers 2>/dev/null | wc -l | tr -d ' ')
    [ "${FOUND}" -ge 3 ] && break
    sleep 10
  done

  if [ "${FOUND:-0}" -ge 3 ]; then
    kubectl rollout status deployment/flask-api-flask-api -n "${NAMESPACE}" --timeout=5m
    kubectl rollout status deployment/node-api-node-api -n "${NAMESPACE}" --timeout=5m
    kubectl rollout status deployment/web-ui-web-ui -n "${NAMESPACE}" --timeout=5m
  else
    echo '  WARN: the apps have not appeared after 5 minutes.'
    echo '        Argo CD is installed; the sync is what is stuck. Check:'
    echo '          kubectl get applications -n argocd'
    echo '          kubectl describe application flask-api -n argocd | tail -30'
    echo '        The usual cause is a repoURL/branch in gitops/ that does not'
    echo '        match a commit you have actually pushed.'
  fi
fi

echo '=== Step 11: Public URL (web-ui LoadBalancer) ==='
# The Helm chart names the Service <release>-<svc> = "web-ui-web-ui".
HOSTNAME=$(kubectl get svc web-ui-web-ui -n "${NAMESPACE}" \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
if [ -n "${HOSTNAME}" ]; then
  echo "  http://${HOSTNAME}"
else
  echo '  (ALB still provisioning: wait 60-90s and re-check with:'
  echo '   kubectl get svc web-ui-web-ui -n platform)'
fi

echo
echo '=== What is new in V8 (beyond V7) ==='
echo '  gitops/         — Argo CD owns the app deploys now. Change what runs by'
echo '                    committing to gitops/apps/'"${ENV}"'/, not by re-running'
echo '                    this script:'
echo '                      ./scripts/promote_image_v8.sh <sha> '"${ENV}"
echo '  governance/     — Gatekeeper policies, enforcing at admission. Try:'
echo '                      kubectl run bad --image=nginx:latest -n platform'
echo '  Argo CD UI      — kubectl port-forward -n argocd svc/argocd-server 8081:80'
echo
echo '=== Carried over from V7, unchanged ==='
echo '  monitoring/     — local docker-compose stack: docker compose up --build -d'
echo '  sre/incidents/  — incident-response intro: see sre/incidents/README.md'
echo '  scripts/risk_score.sh — a one-script introduction to AIOps-style risk scoring'
