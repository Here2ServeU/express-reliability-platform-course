#!/bin/bash
set -e
REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_BASE="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/reliability-platform"

echo '--- Authenticating Docker to ECR ---'
aws ecr get-login-password --region $REGION | \
  docker login --username AWS --password-stdin \
  ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

echo '--- Building, tagging, and pushing all images (linux/amd64 for Fargate) ---'
# Fargate runs linux/amd64 by default. Without --platform, docker on Apple
# Silicon builds arm64-only images and ECS fails with "image Manifest does
# not contain descriptor matching platform 'linux/amd64'".
for SVC in flask-api node-api web-ui; do
  echo "Building $SVC..."
  docker build --platform linux/amd64 -t ${SVC}:latest ./apps/${SVC}

  echo "Tagging $SVC..."
  docker tag ${SVC}:latest ${ECR_BASE}/${SVC}:latest

  echo "Pushing $SVC..."
  docker push ${ECR_BASE}/${SVC}:latest

  echo "Done: $SVC"
done
echo "All three images in ECR."
