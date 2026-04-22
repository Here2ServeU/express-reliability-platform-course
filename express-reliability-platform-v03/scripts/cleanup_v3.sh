#!/bin/bash
REGION="us-east-1"
CLUSTER="reliability-platform-v03"
echo '=== V3 Cleanup ==='

echo 'Step 1: Scale services to zero (required before deletion)...'
for SVC in web-ui node-api flask-api; do
  aws ecs update-service --cluster $CLUSTER --service $SVC --desired-count 0 --region $REGION 2>/dev/null || true
done
sleep 30

echo 'Step 2: Delete ECS services...'
for SVC in web-ui node-api flask-api; do
  aws ecs delete-service --cluster $CLUSTER --service $SVC --force --region $REGION 2>/dev/null || true
done

echo 'Step 3: Delete ECS cluster...'
aws ecs delete-cluster --cluster $CLUSTER --region $REGION 2>/dev/null || true

echo 'Step 4: Delete ECR repositories and all images...'
for SVC in flask-api node-api web-ui; do
  aws ecr delete-repository --repository-name reliability-platform/$SVC --force --region $REGION 2>/dev/null || true
done

echo 'Step 5: Detach policy and delete IAM role...'
aws iam detach-role-policy --role-name ecsExecRole-v03 \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy 2>/dev/null || true
aws iam delete-role --role-name ecsExecRole-v03 2>/dev/null || true

echo 'Step 6: Prune local Docker...'
docker system prune -f

echo 'Verifying...'
aws ecs list-clusters --region $REGION
echo '=== V3 Cleanup Complete ==='
