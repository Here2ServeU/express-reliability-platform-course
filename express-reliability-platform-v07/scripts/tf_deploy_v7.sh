#!/bin/bash
###############################################################################
# V7 end-to-end deploy.
#
# Order:
#   1. bootstrap     — state bucket + lock table + 3 ECR repos
#   2. build/push    — linux/amd64 images to ECR
#   3. shared layer  — VPC + subnets + IGW (its own state file)
#   4. live  layer   — EKS via the reusable module (its own state file,
#                      reads shared via terraform_remote_state)
#   5. helm install  — flask-api, node-api, web-ui into the platform namespace
#
# This is the LOCAL deploy path. CI runs the same shared → live → apps
# sequence in .github/workflows/deploy.yml; bootstrap + image push are
# expected to be done locally (or in a one-off setup workflow) so the
# repeated CI runs only manage the layers and apps.
###############################################################################
set -euo pipefail

REGION="us-east-1"
PROJECT="reliability-platform"
NAMESPACE="platform"
SERVICES=(flask-api node-api web-ui)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
V7_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo '=== Step 1: Apply V7 bootstrap (state bucket, lock table, ECR repos) ==='
terraform -chdir="${V7_ROOT}/terraform/bootstrap" init -input=false
terraform -chdir="${V7_ROOT}/terraform/bootstrap" apply -auto-approve

echo '=== Step 2: Read bootstrap outputs ==='
STATE_BUCKET=$(terraform -chdir="${V7_ROOT}/terraform/bootstrap" output -raw state_bucket)
LOCK_TABLE=$(terraform -chdir="${V7_ROOT}/terraform/bootstrap" output -raw lock_table)
ECR_BASE=$(terraform -chdir="${V7_ROOT}/terraform/bootstrap" output -raw ecr_base_uri)

echo "  state bucket: ${STATE_BUCKET}"
echo "  lock table:   ${LOCK_TABLE}"
echo "  ECR base:     ${ECR_BASE}"

echo '=== Step 3: Build and push images from this repo apps/ ==='
"${SCRIPT_DIR}/build_push_images_v7.sh"

echo '=== Step 4: Initialize SHARED layer against V7 bootstrap backend ==='
# -reconfigure forces re-init so the literal YOUR_ACCOUNT_ID in main.tf gets
# overridden by the real bucket name. Without this, a stale .terraform/
# from a prior run could pin the literal.
terraform -chdir="${V7_ROOT}/terraform/shared" init \
  -reconfigure -input=false \
  -backend-config="bucket=${STATE_BUCKET}" \
  -backend-config="region=${REGION}" \
  -backend-config="dynamodb_table=${LOCK_TABLE}" \
  -backend-config="key=shared/v7/terraform.tfstate"

echo '=== Step 5: Apply SHARED Terraform (VPC, subnets, IGW — ~1 min) ==='
terraform -chdir="${V7_ROOT}/terraform/shared" apply -auto-approve

echo '=== Step 6: Initialize LIVE layer against V7 bootstrap backend ==='
terraform -chdir="${V7_ROOT}/terraform/live" init \
  -reconfigure -input=false \
  -backend-config="bucket=${STATE_BUCKET}" \
  -backend-config="region=${REGION}" \
  -backend-config="dynamodb_table=${LOCK_TABLE}" \
  -backend-config="key=live/v7/terraform.tfstate"

echo '=== Step 7: Apply LIVE Terraform (EKS via module — 10-15 minutes) ==='
# Pass state_bucket so the live layer's terraform_remote_state data source
# reads from the V7 bucket instead of the YOUR_ACCOUNT_ID literal.
terraform -chdir="${V7_ROOT}/terraform/live" apply -auto-approve \
  -var "state_bucket=${STATE_BUCKET}"

echo '=== Step 8: Configure kubectl for the new cluster ==='
CLUSTER=$(terraform -chdir="${V7_ROOT}/terraform/live" output -raw cluster_name)
aws eks --region "${REGION}" update-kubeconfig --name "${CLUSTER}"
kubectl get nodes

echo '=== Step 9: Create platform namespace (idempotent) ==='
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo '=== Step 10: Install/upgrade Helm charts with V7 ECR images ==='
# --set image.repository overrides the YOUR_ACCOUNT_ID placeholder in each
# chart's values.yaml without modifying the file in place. Tag stays at the
# values.yaml default ("latest") — override per-call with --set image.tag=<sha>
# for traceable deploys.
for SVC in "${SERVICES[@]}"; do
  helm upgrade --install "${SVC}" "${V7_ROOT}/helm/${SVC}" \
    --namespace "${NAMESPACE}" \
    --set image.repository="${ECR_BASE}/${SVC}"
done

echo '=== Step 11: Wait for all pods Ready ==='
kubectl rollout status deployment/flask-api-flask-api -n "${NAMESPACE}"
kubectl rollout status deployment/node-api-node-api -n "${NAMESPACE}"
kubectl rollout status deployment/web-ui-web-ui -n "${NAMESPACE}"

echo '=== Step 12: Public URL (web-ui LoadBalancer) ==='
HOSTNAME=$(kubectl get svc web-ui-web-ui -n "${NAMESPACE}" \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
if [ -n "${HOSTNAME}" ]; then
  echo "  http://${HOSTNAME}"
else
  echo '  (ALB still provisioning — wait 60-90s and re-check with:'
  echo '   kubectl get svc web-ui-web-ui -n platform)'
fi
