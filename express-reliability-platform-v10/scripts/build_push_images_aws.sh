#!/bin/bash
# Build and push all three service images to ECR.
# Images are tagged with the git commit SHA (never :latest), so every
# deploy is traceable and Gatekeeper's no-latest-tag policy passes.
# Prints the tag on the last line for deploy_aws.sh.
set -euo pipefail

ECR_BASE=$(terraform -chdir=platform/terraform/aws/bootstrap output -raw ecr_base)
REGION="${AWS_REGION:-us-east-1}"
TAG="${TAG:-$(git rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)}"

aws ecr get-login-password --region "$REGION" | \
  docker login --username AWS --password-stdin "$(echo "$ECR_BASE" | cut -d/ -f1)" >&2

for SVC in flask-api node-api web-ui; do
  echo "Building and pushing: ${SVC}:${TAG}" >&2
  docker buildx build --platform linux/amd64 \
    -t "${ECR_BASE}/${SVC}:${TAG}" --push "./apps/${SVC}" >&2
done

echo "All three images pushed to ECR." >&2
echo "$TAG"
