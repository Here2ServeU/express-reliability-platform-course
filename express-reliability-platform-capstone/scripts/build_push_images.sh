#!/bin/bash
# Build and push all three service images to ECR.
set -e

ECR_BASE=$(terraform -chdir=platform/terraform/bootstrap output -raw ecr_base)
REGION="${AWS_REGION:-us-east-1}"

aws ecr get-login-password --region "$REGION" | \
  docker login --username AWS --password-stdin "$(echo "$ECR_BASE" | cut -d/ -f1)"

for SVC in flask-api node-api web-ui; do
  echo "Building and pushing: ${SVC}"
  docker buildx build --platform linux/amd64 \
    -t "${ECR_BASE}/${SVC}:latest" --push "./apps/${SVC}"
done

echo "All three images pushed to ECR."
