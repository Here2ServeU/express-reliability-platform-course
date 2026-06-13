#!/bin/bash
set -e
REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Creating ECR repositories in ${REGION}..."

for REPO in reliability-platform/flask-api \
            reliability-platform/node-api \
            reliability-platform/web-ui; do
  aws ecr create-repository \
    --repository-name "${REPO}" \
    --region "${REGION}" \
    --image-scanning-configuration scanOnPush=true 2>/dev/null || true
  echo "Repository ready: ${REPO}"
done

echo "All ECR repositories created."
echo "Base URI: ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
