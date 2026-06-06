#!/bin/bash
REGION="us-east-1"
CLUSTER="reliability-platform-v04"

echo '=== Public IPs of Running Tasks ==='
for SVC in flask-api node-api web-ui; do
  echo "--- $SVC ---"
  TASK=$(aws ecs list-tasks \
    --cluster $CLUSTER --service-name $SVC \
    --query 'taskArns[0]' --output text --region $REGION 2>/dev/null)
  if [ -z "$TASK" ] || [ "$TASK" = "None" ]; then
    echo "  No task running yet. Wait 90 seconds and try again."
    continue
  fi
  ENI=$(aws ecs describe-tasks \
    --cluster $CLUSTER --tasks $TASK --region $REGION \
    --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
    --output text)
  IP=$(aws ec2 describe-network-interfaces \
    --network-interface-ids $ENI --region $REGION \
    --query 'NetworkInterfaces[0].Association.PublicIp' --output text)
  echo "  Public IP: $IP"
done
