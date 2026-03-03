#!/bin/bash
# Build, tag, and push Docker images to ECR
set -e
AWS_REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
for service in node-api flask-api web-ui; do
  docker build -t $service ./apps/$service
  docker tag $service:latest $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$service:latest
  aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
  docker push $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$service:latest
done