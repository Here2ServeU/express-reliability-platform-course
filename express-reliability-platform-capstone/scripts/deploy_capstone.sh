#!/bin/bash
# deploy_capstone.sh — one command brings up the complete platform.
set -e
REGION="${AWS_REGION:-us-east-1}"
NAMESPACE="platform"

echo '=== Step 1: Bootstrap (S3 state + DynamoDB lock + ECR repos) ==='
terraform -chdir=platform/terraform/bootstrap init -input=false
terraform -chdir=platform/terraform/bootstrap apply -auto-approve
BUCKET=$(terraform -chdir=platform/terraform/bootstrap output -raw state_bucket)

echo '=== Step 2: Build and push images to ECR ==='
./scripts/build_push_images.sh

echo '=== Step 3: Deploy shared layer (VPC, subnets) ==='
terraform -chdir=platform/terraform/shared init -reconfigure -input=false
terraform -chdir=platform/terraform/shared apply -auto-approve

echo '=== Step 4: Deploy live layer (EKS cluster) ==='
terraform -chdir=platform/terraform/live init -reconfigure -input=false
terraform -chdir=platform/terraform/live apply -auto-approve -var "state_bucket=${BUCKET}"
CLUSTER=$(terraform -chdir=platform/terraform/live output -raw cluster_name)
aws eks --region "$REGION" update-kubeconfig --name "$CLUSTER"

echo '=== Step 5: Install Helm charts ==='
ECR_BASE=$(terraform -chdir=platform/terraform/bootstrap output -raw ecr_base)
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
for SVC in flask-api node-api web-ui; do
  helm upgrade --install "$SVC" "platform/helm/${SVC}" \
    --namespace "$NAMESPACE" \
    --set image.repository="${ECR_BASE}/${SVC}"
done

echo '=== Step 6: Apply governance (OPA Gatekeeper) ==='
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/v3.14.0/deploy/gatekeeper.yaml
sleep 60
kubectl apply -f governance/gatekeeper/templates/
sleep 10
kubectl apply -f governance/gatekeeper/constraints/
kubectl apply -f governance/namespaces/platform-ns.yaml

echo '=== Step 7: Deploy monitoring ==='
kubectl apply -f monitoring/ 2>/dev/null || echo "  (apply monitoring via your Prometheus/Grafana stack)"

echo '================================================='
echo 'Capstone deployment complete.'
echo '================================================='
