#!/bin/bash
set -euo pipefail

REGION="us-east-1"
PROJECT="reliability-platform"
NAMESPACE="platform"
SERVICES=(flask-api node-api web-ui)

echo '=== Step 1: Apply V6 bootstrap (S3 state bucket + DynamoDB lock table) ==='
# V6 has its own bootstrap — own bucket name, own lock table name — so V5 and
# V6 can coexist on the same AWS account without colliding. See
# platform/terraform/bootstrap/main.tf for the resource names.
terraform -chdir=platform/terraform/bootstrap init -input=false
terraform -chdir=platform/terraform/bootstrap apply -auto-approve

echo '=== Step 2: Read bootstrap outputs and ECR base URI ==='
STATE_BUCKET=$(terraform -chdir=platform/terraform/bootstrap output -raw state_bucket)
LOCK_TABLE=$(terraform -chdir=platform/terraform/bootstrap output -raw lock_table)
ACCOUNT_ID=$(terraform -chdir=platform/terraform/bootstrap output -raw account_id)
ECR_BASE="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${PROJECT}"

echo "  state bucket: ${STATE_BUCKET}"
echo "  lock table:   ${LOCK_TABLE}"
echo "  ECR base:     ${ECR_BASE}"

# V6 has its own state backend now, but it still reuses V5's ECR repos. Fail
# fast with an actionable message if those are gone — kubelet would otherwise
# show ImagePullBackOff on every pod and the cause would be hard to find.
for SVC in "${SERVICES[@]}"; do
  if ! aws ecr describe-repositories --region "${REGION}" \
        --repository-names "${PROJECT}/${SVC}" >/dev/null 2>&1; then
    echo "ERROR: ECR repo ${PROJECT}/${SVC} not found in ${REGION}." >&2
    echo "       V6 reuses images V5 pushed. Re-run V5's tf_deploy.sh to recreate the repos." >&2
    exit 1
  fi
done

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
HOSTNAME=$(kubectl get svc web-ui -n "${NAMESPACE}" \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
if [ -n "${HOSTNAME}" ]; then
  echo "  http://${HOSTNAME}"
else
  echo '  (ALB still provisioning — wait 60-90s and re-check with:'
  echo '   kubectl get svc web-ui -n platform)'
fi
