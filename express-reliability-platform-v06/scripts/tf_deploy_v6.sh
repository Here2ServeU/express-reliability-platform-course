#!/bin/bash
set -euo pipefail

REGION="us-east-1"
PROJECT="reliability-platform"
NAMESPACE="platform"
SERVICES=(flask-api node-api web-ui)

echo '=== Step 1: Apply V6 bootstrap (state bucket, lock table, ECR repos) ==='
# V6 owns its full bootstrap: state backend AND the three ECR repos. V5 stays
# untouched — we no longer depend on V5's terraform having been applied.
# See platform/terraform/bootstrap/{main,ecr}.tf.
terraform -chdir=platform/terraform/bootstrap init -input=false
terraform -chdir=platform/terraform/bootstrap apply -auto-approve

echo '=== Step 2: Read bootstrap outputs ==='
STATE_BUCKET=$(terraform -chdir=platform/terraform/bootstrap output -raw state_bucket)
LOCK_TABLE=$(terraform -chdir=platform/terraform/bootstrap output -raw lock_table)
ECR_BASE=$(terraform -chdir=platform/terraform/bootstrap output -raw ecr_base_uri)

echo "  state bucket: ${STATE_BUCKET}"
echo "  lock table:   ${LOCK_TABLE}"
echo "  ECR base:     ${ECR_BASE}"

echo '=== Step 2b: Build and push images (sources from V5 apps/ by default) ==='
# Done before the EKS apply so when Helm install runs in step 7 the images are
# already pullable. Override APPS_SRC if your Dockerfiles live elsewhere.
"${0%/*}/build_push_images_v6.sh"

echo '=== Step 3: Initialize EKS stack against V6 bootstrap backend ==='
terraform -chdir=platform/terraform/eks init \
  -reconfigure -input=false \
  -backend-config="bucket=${STATE_BUCKET}" \
  -backend-config="region=${REGION}" \
  -backend-config="dynamodb_table=${LOCK_TABLE}" \
  -backend-config="key=eks/v6/terraform.tfstate"

echo '=== Step 4: Apply EKS Terraform (10-15 minutes) ==='
terraform -chdir=platform/terraform/eks apply -auto-approve

echo '=== Step 5: Configure kubectl for the new cluster ==='
CLUSTER=$(terraform -chdir=platform/terraform/eks output -raw cluster_name)
aws eks --region "${REGION}" update-kubeconfig --name "${CLUSTER}"
kubectl get nodes

echo '=== Step 6: Create platform namespace (idempotent) ==='
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo '=== Step 7: Install/upgrade Helm charts with V5 ECR images ==='
# --set image.repository overrides the YOUR_ACCOUNT_ID placeholder in each
# chart's values.yaml without modifying the file in place. Tag stays at the
# values.yaml default ("latest") — override per-call with --set image.tag=<sha>
# for traceable deploys.
for SVC in "${SERVICES[@]}"; do
  helm upgrade --install "${SVC}" "platform/helm/${SVC}" \
    --namespace "${NAMESPACE}" \
    --set image.repository="${ECR_BASE}/${SVC}"
done

echo '=== Step 8: Wait for all pods Ready ==='
kubectl rollout status deployment/flask-api-flask-api -n "${NAMESPACE}"
kubectl rollout status deployment/node-api-node-api -n "${NAMESPACE}"
kubectl rollout status deployment/web-ui-web-ui -n "${NAMESPACE}"

echo '=== Step 9: Public URL (web-ui LoadBalancer) ==='
# The Helm chart names the Service <release>-<svc> = "web-ui-web-ui".
HOSTNAME=$(kubectl get svc web-ui-web-ui -n "${NAMESPACE}" \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
if [ -n "${HOSTNAME}" ]; then
  echo "  http://${HOSTNAME}"
else
  echo '  (ALB still provisioning — wait 60-90s and re-check with:'
  echo '   kubectl get svc web-ui-web-ui -n platform)'
fi
