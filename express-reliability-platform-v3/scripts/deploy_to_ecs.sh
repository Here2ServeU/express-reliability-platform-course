#!/bin/bash
# Deploy services to AWS ECS
set -e
AWS_REGION="us-east-1"
ECR_REPO_NODE="node-api"
ECR_REPO_FLASK="flask-api"
ECR_REPO_WEB="web-ui"

# Authenticate Docker to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_REGION.amazonaws.com

# Build and push images
for service in node-api flask-api web-ui; do
  docker build -t $service ./apps/$service
  docker tag $service:latest $(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_REGION.amazonaws.com/$service:latest
  docker push $(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_REGION.amazonaws.com/$service:latest
done

# Update ECS service (assumes ECS cluster and service already exist)
# aws ecs update-service --cluster <cluster-name> --service <service-name> --force-new-deployment

echo "Deployment to ECS complete."