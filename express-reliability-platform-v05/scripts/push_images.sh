#!/bin/bash
set -e
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=us-east-1
ECR_BASE=${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/reliability-platform

# Log in to ECR
aws ecr get-login-password --region ${REGION} | \
  docker login --username AWS --password-stdin \
  ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

# Build for linux/amd64 — EKS worker nodes run on x86-64 (Intel/AMD)
# If you have an Apple Silicon Mac (M1/M2/M3), your Mac builds arm64 by default.
# Without --platform linux/amd64, EKS shows: 'image cannot run on platform linux/amd64'
for SVC in flask-api node-api web-ui; do
  echo "Building and pushing: ${SVC}"
  docker buildx build --platform linux/amd64 \
    -t ${ECR_BASE}/${SVC}:latest --push ./apps/${SVC}
done

echo "All three images are in ECR. Ready to deploy to Kubernetes."
