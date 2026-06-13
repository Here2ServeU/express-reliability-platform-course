#!/bin/bash
set -e
REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_BASE=${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/reliability-platform

echo "Building and pushing images to ECR..."

for SVC in flask-api node-api web-ui; do
  echo "Building: ${SVC}"

  # IMPORTANT: --platform linux/amd64 is required.
  # Amazon's computers run on linux/amd64.
  # If you have a Mac with Apple Silicon (M1/M2/M3),
  # your Mac builds arm64 images by default.
  # Without this flag, Amazon will refuse to run your image.
  docker build --platform linux/amd64 -t ${SVC}:latest ./apps/${SVC}

  # Put the Amazon address on the package as a label
  docker tag ${SVC}:latest ${ECR_BASE}/${SVC}:latest

  # Ship the package to Amazon
  docker push ${ECR_BASE}/${SVC}:latest

  echo "Shipped: ${ECR_BASE}/${SVC}:latest"
done

echo "All three images are now in ECR. Ready to deploy."
