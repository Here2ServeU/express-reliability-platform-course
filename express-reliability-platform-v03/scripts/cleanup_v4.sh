#!/bin/bash
# Tear down everything deploy_ecs.sh creates, including the dedicated VPC.
# Order matters: services -> cluster -> ENIs -> SG -> subnets -> RT -> IGW -> VPC.

REGION="us-east-1"
CLUSTER="reliability-platform-v04"
VPC_NAME="reliability-platform-v04-vpc"
SG_NAME="reliability-sg-v04"

echo '=== V4 Cleanup ==='

echo 'Step 1: Scale services to zero (required before deletion)...'
for SVC in web-ui node-api flask-api; do
  aws ecs update-service --cluster $CLUSTER --service $SVC \
    --desired-count 0 --region $REGION 2>/dev/null || true
done
sleep 30

echo 'Step 2: Delete ECS services...'
for SVC in web-ui node-api flask-api; do
  aws ecs delete-service --cluster $CLUSTER --service $SVC \
    --force --region $REGION 2>/dev/null || true
done

echo 'Step 3: Delete ECS cluster...'
aws ecs delete-cluster --cluster $CLUSTER --region $REGION 2>/dev/null || true

echo 'Step 4: Delete CloudWatch log groups...'
for SVC in flask-api node-api web-ui; do
  aws logs delete-log-group --log-group-name "/ecs/v04/$SVC" \
    --region $REGION 2>/dev/null || true
done

echo 'Step 5: Delete ECR repositories and all images...'
for SVC in flask-api node-api web-ui; do
  aws ecr delete-repository --repository-name reliability-platform/$SVC \
    --force --region $REGION 2>/dev/null || true
done

echo 'Step 6: Detach policy and delete IAM role...'
aws iam detach-role-policy --role-name ecsExecRole-v04 \
  --policy-arn arn:aws:iam:aws:policy/service-role/AmazonECSTaskExecutionRolePolicy 2>/dev/null || true
aws iam delete-role --role-name ecsExecRole-v04 2>/dev/null || true

# ---------- Network teardown ----------

echo 'Step 7: Locate VPC...'
VPC_ID=$(aws ec2 describe-vpcs \
  --filters Name=tag:Name,Values=$VPC_NAME \
  --query 'Vpcs[0].VpcId' --output text --region $REGION 2>/dev/null)

if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
  echo "  No VPC named $VPC_NAME found. Skipping network teardown."
else
  echo "  VPC: $VPC_ID"

  echo 'Step 8: Wait for Fargate ENIs to clear (up to 90s)...'
  # Fargate tasks leave ENIs behind that block SG/subnet deletion. They auto-
  # release after services are deleted, but it can take a minute.
  for attempt in 1 2 3 4 5 6 7 8 9; do
    ENI_COUNT=$(aws ec2 describe-network-interfaces \
      --filters Name=vpc-id,Values=$VPC_ID \
      --query 'length(NetworkInterfaces)' \
      --output text --region $REGION 2>/dev/null)
    if [ "$ENI_COUNT" = "0" ]; then break; fi
    echo "  $ENI_COUNT ENI(s) still present, waiting 10s..."
    sleep 10
  done
  # Force-delete anything left over (best effort).
  for ENI in $(aws ec2 describe-network-interfaces \
        --filters Name=vpc-id,Values=$VPC_ID \
        --query 'NetworkInterfaces[].NetworkInterfaceId' \
        --output text --region $REGION 2>/dev/null); do
    aws ec2 delete-network-interface --network-interface-id $ENI \
      --region $REGION 2>/dev/null || true
  done

  echo 'Step 9: Delete security group...'
  SG_ID=$(aws ec2 describe-security-groups \
    --filters Name=group-name,Values=$SG_NAME Name=vpc-id,Values=$VPC_ID \
    --query 'SecurityGroups[0].GroupId' --output text --region $REGION 2>/dev/null)
  if [ -n "$SG_ID" ] && [ "$SG_ID" != "None" ]; then
    aws ec2 delete-security-group --group-id $SG_ID --region $REGION 2>/dev/null \
      && echo "  Deleted SG: $SG_ID" \
      || echo "  Could not delete SG $SG_ID (may have lingering dependencies)."
  fi

  echo 'Step 10: Disassociate and delete route tables...'
  # Disassociate every non-main association in this VPC, then delete the
  # custom route tables (the "main" RT is deleted with the VPC).
  for RT_ID in $(aws ec2 describe-route-tables \
        --filters Name=vpc-id,Values=$VPC_ID \
        --query 'RouteTables[].RouteTableId' \
        --output text --region $REGION 2>/dev/null); do
    for ASSOC in $(aws ec2 describe-route-tables \
          --route-table-ids $RT_ID \
          --query 'RouteTables[0].Associations[?Main==`false`].RouteTableAssociationId' \
          --output text --region $REGION 2>/dev/null); do
      aws ec2 disassociate-route-table --association-id $ASSOC \
        --region $REGION 2>/dev/null || true
    done
    # Skip the main RT: AWS deletes it when the VPC is removed.
    IS_MAIN=$(aws ec2 describe-route-tables --route-table-ids $RT_ID \
      --query 'RouteTables[0].Associations[?Main==`true`] | length(@)' \
      --output text --region $REGION 2>/dev/null)
    if [ "$IS_MAIN" = "0" ]; then
      aws ec2 delete-route-table --route-table-id $RT_ID \
        --region $REGION 2>/dev/null \
        && echo "  Deleted route table: $RT_ID" || true
    fi
  done

  echo 'Step 11: Delete subnets...'
  for SUBNET_ID in $(aws ec2 describe-subnets \
        --filters Name=vpc-id,Values=$VPC_ID \
        --query 'Subnets[].SubnetId' \
        --output text --region $REGION 2>/dev/null); do
    aws ec2 delete-subnet --subnet-id $SUBNET_ID --region $REGION 2>/dev/null \
      && echo "  Deleted subnet: $SUBNET_ID" \
      || echo "  Could not delete subnet $SUBNET_ID."
  done

  echo 'Step 12: Detach and delete Internet Gateway...'
  IGW_ID=$(aws ec2 describe-internet-gateways \
    --filters Name=attachment.vpc-id,Values=$VPC_ID \
    --query 'InternetGateways[0].InternetGatewayId' \
    --output text --region $REGION 2>/dev/null)
  if [ -n "$IGW_ID" ] && [ "$IGW_ID" != "None" ]; then
    aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID \
      --vpc-id $VPC_ID --region $REGION 2>/dev/null || true
    aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID \
      --region $REGION 2>/dev/null \
      && echo "  Deleted IGW: $IGW_ID" || true
  fi

  echo 'Step 13: Delete VPC...'
  aws ec2 delete-vpc --vpc-id $VPC_ID --region $REGION 2>/dev/null \
    && echo "  Deleted VPC: $VPC_ID" \
    || echo "  Could not delete VPC $VPC_ID: check the AWS console for stragglers."
fi

# ---------- End network teardown ----------

echo 'Step 14: Prune local Docker...'
docker system prune -f

echo 'Verifying...'
aws ecs list-clusters --region $REGION
aws ec2 describe-vpcs \
  --filters Name=tag:Name,Values=$VPC_NAME \
  --query 'Vpcs[].VpcId' --output text --region $REGION

echo '=== V4 Cleanup Complete ==='
