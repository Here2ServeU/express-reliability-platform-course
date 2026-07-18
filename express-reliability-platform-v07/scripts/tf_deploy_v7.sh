#!/bin/bash
###############################################################################
# Deploy V7 against a specific environment (dev, staging, or prod).
#
# Usage:
#   ENV=dev  ./scripts/tf_deploy_v7.sh   # default if ENV unset
#   ENV=prod ./scripts/tf_deploy_v7.sh
#
# Per-env behavior:
#   - tfvars file:   platform/terraform/eks/environments/<env>.tfvars
#   - state key:     eks/v7/<env>/terraform.tfstate  (env-scoped: dev and
#                    prod never share state or fight over the lock)
#   - cluster name:  reliability-platform-<env>      (set by root locals)
#
# Same shape as V6's tf_deploy_v6.sh — bootstrap, build/push, EKS apply,
# Helm install — with one addition: Step 8 installs the monitoring stack
# (Prometheus/Grafana/Alertmanager) alongside the app charts.
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

echo '=== Step 1: Apply V7 bootstrap (state bucket, lock table, ECR repos) ==='
# V7 owns its full bootstrap: state backend AND the three ECR repos. V6 stays
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

echo '=== Step 2b: Build and push images (from this repo's apps/) ==='
"${0%/*}/build_push_images_v7.sh"

echo "=== Step 3: Initialize EKS stack against V7 bootstrap backend (${ENV}) ==="
# State key is per-env so dev and prod live in separate state files in the
# same bucket. -reconfigure tolerates switching between envs in the same
# clone (different state key each time).
terraform -chdir=platform/terraform/eks init \
  -reconfigure -input=false \
  -backend-config="bucket=${STATE_BUCKET}" \
  -backend-config="region=${REGION}" \
  -backend-config="dynamodb_table=${LOCK_TABLE}" \
  -backend-config="key=eks/v7/${ENV}/terraform.tfstate"

echo "=== Step 4: Apply EKS Terraform for ${ENV} (10-15 minutes) ==="
terraform -chdir=platform/terraform/eks apply -auto-approve \
  -var-file="environments/${ENV}.tfvars"

echo '=== Step 5: Configure kubectl for the new cluster ==='
CLUSTER=$(terraform -chdir=platform/terraform/eks output -raw cluster_name)
aws eks --region "${REGION}" update-kubeconfig --name "${CLUSTER}"
kubectl get nodes

echo '=== Step 6: Create platform namespace (idempotent) ==='
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo '=== Step 7: Install/upgrade Helm charts with V7 ECR images ==='
# --set image.repository overrides the YOUR_ACCOUNT_ID placeholder in each
# chart's values.yaml without modifying the file in place. Tag stays at the
# values.yaml default ("latest"): override per-call with --set image.tag=<sha>
# for traceable deploys.
for SVC in "${SERVICES[@]}"; do
  helm upgrade --install "${SVC}" "platform/helm/${SVC}" \
    --namespace "${NAMESPACE}" \
    --set image.repository="${ECR_BASE}/${SVC}"
done

echo '=== Step 7b: Force rollout so :latest picks up the new image ==='
# Helm only restarts pods when the rendered manifest changes. Because we tag
# images :latest, the Deployment spec is identical across deploys and Helm
# skips the rollout: the old pod keeps the cached image. `rollout restart`
# bumps a template annotation, which (with pullPolicy: Always) makes the new
# pod re-pull. Drop this step if you switch to digest/sha-based tags.
for SVC in "${SERVICES[@]}"; do
  kubectl rollout restart "deployment/${SVC}-${SVC}" -n "${NAMESPACE}"
done

echo '=== Step 8: Wait for all pods Ready ==='
kubectl rollout status deployment/flask-api-flask-api -n "${NAMESPACE}"
kubectl rollout status deployment/node-api-node-api -n "${NAMESPACE}"
kubectl rollout status deployment/web-ui-web-ui -n "${NAMESPACE}"

echo '=== Step 9: Install monitoring stack (Prometheus/Grafana/Alertmanager) ==='
# New in V7. Uses the community kube-prometheus-stack chart with V7's values
# (platform/helm/global-monitoring/values.yaml) — same alert rules as the
# local docker-compose stack, deployed cluster-wide. Set SKIP_MONITORING=true
# to skip this step (e.g. re-running the script just to redeploy apps).
if [ "${SKIP_MONITORING:-false}" != "true" ]; then
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
  helm repo update prometheus-community >/dev/null 2>&1 || true
  helm upgrade --install global-monitoring prometheus-community/kube-prometheus-stack \
    --namespace monitoring --create-namespace \
    -f platform/helm/global-monitoring/values.yaml
else
  echo '  SKIP_MONITORING=true — skipping.'
fi

echo '=== Step 10: Public URL (web-ui LoadBalancer) ==='
# The Helm chart names the Service <release>-<svc> = "web-ui-web-ui".
HOSTNAME=$(kubectl get svc web-ui-web-ui -n "${NAMESPACE}" \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
if [ -n "${HOSTNAME}" ]; then
  echo "  http://${HOSTNAME}"
else
  echo '  (ALB still provisioning: wait 60-90s and re-check with:'
  echo '   kubectl get svc web-ui-web-ui -n platform)'
fi

echo
echo '=== What is new in V7 (beyond V6) ==='
echo '  monitoring/     — local docker-compose stack: docker compose up --build -d'
echo '  sre/incidents/  — incident-response intro: see sre/incidents/README.md'
echo '  scripts/risk_score.sh — a one-script introduction to AIOps-style risk scoring'
