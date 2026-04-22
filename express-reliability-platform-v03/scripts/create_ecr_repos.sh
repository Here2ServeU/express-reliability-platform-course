#!/bin/bash
set -e
REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Account ID: $ACCOUNT_ID"

for SVC in flask-api node-api web-ui; do
  echo "Creating ECR repo: reliability-platform/$SVC"
  aws ecr create-repository \
    --repository-name "reliability-platform/${SVC}" \
    --region $REGION \
    --image-scanning-configuration scanOnPush=true \
    2>/dev/null || echo "  Already exists - skipping"
  echo "  URI: ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/reliability-platform/${SVC}"
done
echo "ECR repos ready."
