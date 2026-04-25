#!/bin/bash
set -e
REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_BASE="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/reliability-platform"

echo '=== Step 1: Authenticate and push images ==='
aws ecr get-login-password --region $REGION | \
  docker login --username AWS --password-stdin \
  ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

for SVC in flask-api node-api web-ui; do
  docker build -t ${SVC}:latest ./apps/${SVC}
  docker tag ${SVC}:latest ${ECR_BASE}/${SVC}:latest
  docker push ${ECR_BASE}/${SVC}:latest
done

echo '=== Step 2: Initialize platform Terraform ==='
terraform -chdir=terraform/platform init

echo '=== Step 3: Review the plan ==='
terraform -chdir=terraform/platform plan -out=tfplan

echo '=== Step 4: Apply the plan ==='
terraform -chdir=terraform/platform apply tfplan

echo '=== Step 5: Print the ALB URL ==='
echo 'Platform URL:'
terraform -chdir=terraform/platform output alb_dns_name
echo 'Wait 3-5 minutes for tasks to start and register with the ALB.'
