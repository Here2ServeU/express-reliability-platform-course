#!/bin/bash
echo '=== V4 Cleanup ==='

echo 'Destroying platform Terraform (ECS, ALB, ECR, IAM, security groups)...'
terraform -chdir=terraform/platform destroy -auto-approve

echo 'Removing local Docker images...'
docker rmi flask-api:latest node-api:latest web-ui:latest 2>/dev/null || true
docker system prune -f

echo 'Verifying cleanup...'
aws ecs list-clusters --region us-east-1
aws elbv2 describe-load-balancers --region us-east-1 --query \
  'LoadBalancers[*].LoadBalancerName'

echo '=== Done! Bootstrap S3 + DynamoDB KEPT for V5-V10 ==='
