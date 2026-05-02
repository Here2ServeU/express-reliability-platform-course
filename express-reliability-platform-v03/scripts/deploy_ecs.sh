#!/bin/bash
set -e

REGION="us-east-1"
CLUSTER="reliability-platform-v03"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_BASE="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/reliability-platform"

echo '=== Step 0: Ensure ECS service-linked role exists ==='
aws iam create-service-linked-role --aws-service-name ecs.amazonaws.com 2>/dev/null || true
echo "ECS service-linked role ready."

echo '=== Step 1: Get the default VPC and its subnets ==='
VPC_ID=$(aws ec2 describe-vpcs \
  --filters Name=isDefault,Values=true \
  --query 'Vpcs[0].VpcId' --output text --region $REGION)
echo "Default VPC: $VPC_ID"

SUBNETS=$(aws ec2 describe-subnets \
  --filters Name=vpc-id,Values=$VPC_ID \
  --query 'Subnets[*].SubnetId' \
  --output text --region $REGION | tr '\t' ',')
echo "Subnets: $SUBNETS"

echo '=== Step 2: Create ECS cluster ==='
aws ecs create-cluster --cluster-name $CLUSTER --region $REGION 2>/dev/null || true

echo '=== Step 3: Create security group ==='
SG_ID=$(aws ec2 create-security-group \
  --group-name reliability-sg-v03 \
  --description 'V3 Platform SG' \
  --vpc-id $VPC_ID --region $REGION \
  --query 'GroupId' --output text 2>/dev/null || \
  aws ec2 describe-security-groups \
  --filters Name=group-name,Values=reliability-sg-v03 \
  --query 'SecurityGroups[0].GroupId' \
  --output text --region $REGION)
echo "Security Group: $SG_ID"

for PORT in 80 3000 5000; do
  aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID --protocol tcp \
    --port $PORT --cidr 0.0.0.0/0 \
    --region $REGION 2>/dev/null || true
done

echo '=== Step 4: Create IAM Task Execution Role ==='
# FIX: plain URL — no markdown hyperlinks
TRUST='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ecs-tasks.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

aws iam create-role \
  --role-name ecsExecRole-v03 \
  --assume-role-policy-document "$TRUST" 2>/dev/null || true

aws iam attach-role-policy \
  --role-name ecsExecRole-v03 \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy 2>/dev/null || true

EXEC_ROLE="arn:aws:iam::${ACCOUNT_ID}:role/ecsExecRole-v03"

echo '=== Step 5: Create task definitions and services ==='
for SVC in flask-api node-api web-ui; do
  PORT=5000
  [ "$SVC" = "node-api" ] && PORT=3000
  [ "$SVC" = "web-ui"   ] && PORT=80

  CONTAINER_DEF="[{\"name\":\"${SVC}\",\"image\":\"${ECR_BASE}/${SVC}:latest\",\
\"portMappings\":[{\"containerPort\":${PORT}}],\"essential\":true,\
\"logConfiguration\":{\"logDriver\":\"awslogs\",\
\"options\":{\"awslogs-group\":\"/ecs/v03/${SVC}\",\
\"awslogs-region\":\"${REGION}\",\"awslogs-stream-prefix\":\"ecs\",\
\"awslogs-create-group\":\"true\"}}}]"

  aws ecs register-task-definition \
    --family ${SVC}-v03 \
    --network-mode awsvpc \
    --requires-compatibilities FARGATE \
    --cpu 256 --memory 512 \
    --execution-role-arn $EXEC_ROLE \
    --container-definitions "$CONTAINER_DEF" \
    --region $REGION > /dev/null

  aws ecs create-service \
    --cluster $CLUSTER \
    --service-name $SVC \
    --task-definition ${SVC}-v03 \
    --desired-count 1 \
    --launch-type FARGATE \
    --network-configuration \
    "awsvpcConfiguration={subnets=[${SUBNETS}],securityGroups=[${SG_ID}],assignPublicIp=ENABLED}" \
    --region $REGION > /dev/null

  echo "  Launched: $SVC on port $PORT"
done

echo ''
echo '=== Done! Wait 90 seconds, then run get_public_ips.sh ==='
