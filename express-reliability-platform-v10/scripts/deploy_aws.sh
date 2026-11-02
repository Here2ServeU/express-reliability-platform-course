#!/bin/bash
# deploy_aws.sh: one command brings up the complete platform on EKS.
# This is V9's deployment with V10's fixes: SHA image tags and the shared
# platform-workload service account the Helm charts now expect.
#
#   ./scripts/deploy_aws.sh
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
NAMESPACE="platform"
KSA="platform-workload"

echo '=== Step 1: Bootstrap (S3 state + DynamoDB lock + ECR repos) ==='
terraform -chdir=platform/terraform/aws/bootstrap init -input=false
terraform -chdir=platform/terraform/aws/bootstrap apply -auto-approve
BUCKET=$(terraform -chdir=platform/terraform/aws/bootstrap output -raw state_bucket)

echo '=== Step 2: Build and push images to ECR ==='
TAG=$(./scripts/build_push_images_aws.sh | tail -1)
ECR_BASE=$(terraform -chdir=platform/terraform/aws/bootstrap output -raw ecr_base)

echo '=== Step 3: Shared layer (VPC, subnets) ==='
terraform -chdir=platform/terraform/aws/shared init -reconfigure -input=false -backend-config="bucket=${BUCKET}"
terraform -chdir=platform/terraform/aws/shared apply -auto-approve

echo '=== Step 4: Live layer (EKS cluster) ==='
terraform -chdir=platform/terraform/aws/live init -reconfigure -input=false -backend-config="bucket=${BUCKET}"
terraform -chdir=platform/terraform/aws/live apply -auto-approve -var "state_bucket=${BUCKET}"
CLUSTER=$(terraform -chdir=platform/terraform/aws/live output -raw cluster_name)
aws eks --region "$REGION" update-kubeconfig --name "$CLUSTER"

echo '=== Step 5: Namespace + service account ==='
kubectl apply -f governance/namespaces/platform-ns.yaml
kubectl create serviceaccount "$KSA" -n "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo "=== Step 6: Install Helm charts (image tag: ${TAG}) ==="
for SVC in flask-api node-api web-ui; do
  helm upgrade --install "$SVC" "platform/helm/${SVC}" \
    --namespace "$NAMESPACE" \
    --set image.repository="${ECR_BASE}/${SVC}" \
    --set image.tag="${TAG}" \
    --wait --timeout 10m
done

echo '=== Step 7: Governance (OPA Gatekeeper) ==='
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/v3.14.0/deploy/gatekeeper.yaml
kubectl -n gatekeeper-system rollout status deployment/gatekeeper-controller-manager --timeout=180s
kubectl apply -f governance/gatekeeper/templates/
sleep 10
kubectl apply -f governance/gatekeeper/constraints/

echo '=== Step 8: Monitoring ==='
kubectl apply -f monitoring/ 2>/dev/null || echo "  (apply monitoring via your Prometheus/Grafana stack)"

echo '================================================='
echo 'Platform deployment complete on EKS.'
echo "  Cluster:  ${CLUSTER} (${REGION})"
echo "  Web UI:   kubectl get svc web-ui-web-ui -n ${NAMESPACE}"
echo '================================================='
