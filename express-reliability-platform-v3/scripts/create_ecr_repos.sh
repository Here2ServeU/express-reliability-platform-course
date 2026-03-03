#!/bin/bash
# Create ECR repositories for each service
set -e
AWS_REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
for repo in node-api flask-api web-ui; do
  aws ecr create-repository --repository-name $repo --region $AWS_REGION || echo "$repo already exists"
  echo "ECR repository created: $repo"
done