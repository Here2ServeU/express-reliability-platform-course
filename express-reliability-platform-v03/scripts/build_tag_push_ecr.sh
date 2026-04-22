#!/bin/bash
set -e
REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_BASE="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/reliability-platform"

echo '--- Authenticating Docker to ECR ---'
aws ecr get-login-password --region $REGION | \
  docker login --username AWS --password-stdin \
  ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

echo '--- Building, tagging, and pushing all images ---'
for SVC in flask-api node-api web-ui; do
  echo "Building $SVC..."
  docker build -t ${SVC}:latest ./apps/${SVC}

  echo "Tagging $SVC..."
  docker tag ${SVC}:latest ${ECR_BASE}/${SVC}:latest

  echo "Pushing $SVC..."
  docker push ${ECR_BASE}/${SVC}:latest

  echo "Done: $SVC"
done
echo "All three images in ECR."
