#!/bin/bash
# Deploy the full V10 platform: bootstrap -> shared -> live -> images -> Helm.
set -e

REGION="us-east-1"
NAMESPACE="platform"

echo '=== Step 1: Bootstrap (state bucket, lock table, ECR repos) ==='
terraform -chdir=terraform/bootstrap init -input=false
terraform -chdir=terraform/bootstrap apply -auto-approve
BUCKET=$(terraform -chdir=terraform/bootstrap output -raw state_bucket)

echo '=== Step 2: Shared layer (VPC, subnets) ==='
terraform -chdir=terraform/shared init -reconfigure -input=false
terraform -chdir=terraform/shared apply -auto-approve

echo '=== Step 3: Live layer (EKS cluster) ==='
terraform -chdir=terraform/live init -reconfigure -input=false
terraform -chdir=terraform/live apply -auto-approve -var "state_bucket=${BUCKET}"

echo '=== Step 4: Connect kubectl ==='
CLUSTER=$(terraform -chdir=terraform/live output -raw cluster_name)
aws eks --region "${REGION}" update-kubeconfig --name "${CLUSTER}"

echo '=== Step 5: Build and push images ==='
./scripts/build_push_images_v10.sh

echo '=== Step 6: Install Helm charts ==='
ECR_BASE=$(terraform -chdir=terraform/bootstrap output -raw ecr_base)
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
for SVC in flask-api node-api web-ui; do
  helm upgrade --install "${SVC}" "platform/helm/${SVC}" \
    --namespace "${NAMESPACE}" \
    --set image.repository="${ECR_BASE}/${SVC}"
done

echo '=== V10 deploy complete ==='
