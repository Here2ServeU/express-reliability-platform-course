#!/bin/bash
REGION=us-east-1
CLUSTER=reliability-platform-v03

echo "Finding the public IP for web-ui..."

# Step 1: get the task ID for web-ui
TASK_ARN=$(aws ecs list-tasks \
  --cluster $CLUSTER \
  --service-name web-ui \
  --region $REGION \
  --query 'taskArns[0]' --output text)

echo "Task found: $TASK_ARN"

# Step 2: get the network card ID attached to that task
ENI=$(aws ecs describe-tasks \
  --cluster $CLUSTER \
  --tasks $TASK_ARN \
  --region $REGION \
  --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
  --output text)

# Step 3: get the public IP from that network card
PUBLIC_IP=$(aws ec2 describe-network-interfaces \
  --network-interface-ids $ENI \
  --region $REGION \
  --query 'NetworkInterfaces[0].Association.PublicIp' \
  --output text)

echo ""
echo "Your platform is live at: http://${PUBLIC_IP}"
echo "Open that address in any browser."
