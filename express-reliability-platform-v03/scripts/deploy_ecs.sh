#!/bin/bash
# Note: no `set -e`; we want to keep going if one of the three services fails
# to register or update so the others still get deployed. Errors are reported inline.

REGION="us-east-1"
CLUSTER="reliability-platform-v03"
VPC_NAME="reliability-platform-v03-vpc"
VPC_CIDR="10.42.0.0/16"
SG_NAME="reliability-sg-v03"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_BASE="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/reliability-platform"

echo '=== Step 0: Ensure ECS service-linked role exists ==='
aws iam create-service-linked-role --aws-service-name ecs.amazonaws.com 2>/dev/null || true
echo "ECS service-linked role ready."

echo '=== Step 1: Create dedicated VPC ==='
VPC_ID=$(aws ec2 describe-vpcs \
  --filters Name=tag:Name,Values=$VPC_NAME \
  --query 'Vpcs[0].VpcId' --output text --region $REGION 2>/dev/null)

if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
  echo "Creating VPC $VPC_NAME ($VPC_CIDR)..."
  VPC_ID=$(aws ec2 create-vpc \
    --cidr-block $VPC_CIDR \
    --region $REGION \
    --query 'Vpc.VpcId' --output text)
  aws ec2 create-tags --resources $VPC_ID \
    --tags Key=Name,Value=$VPC_NAME Key=Project,Value=reliability-platform-v03 \
    --region $REGION
  # DNS settings so tasks can resolve ECR + AWS service endpoints.
  aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support \
    --region $REGION
  aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames \
    --region $REGION
  echo "Created VPC: $VPC_ID"
else
  echo "Reusing existing VPC: $VPC_ID"
fi

echo '=== Step 2: Internet Gateway ==='
IGW_ID=$(aws ec2 describe-internet-gateways \
  --filters Name=attachment.vpc-id,Values=$VPC_ID \
  --query 'InternetGateways[0].InternetGatewayId' \
  --output text --region $REGION 2>/dev/null)

if [ "$IGW_ID" = "None" ] || [ -z "$IGW_ID" ]; then
  IGW_ID=$(aws ec2 create-internet-gateway --region $REGION \
    --query 'InternetGateway.InternetGatewayId' --output text)
  aws ec2 create-tags --resources $IGW_ID \
    --tags Key=Name,Value=${VPC_NAME}-igw Key=Project,Value=reliability-platform-v03 \
    --region $REGION
  aws ec2 attach-internet-gateway \
    --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $REGION
  echo "Created and attached IGW: $IGW_ID"
else
  echo "Reusing IGW: $IGW_ID"
fi

echo '=== Step 3: Public subnets (one per AZ, up to 3) ==='
AZS=$(aws ec2 describe-availability-zones --region $REGION \
  --query 'AvailabilityZones[?State==`available`].ZoneName' \
  --output text | xargs)

SUBNETS=""
i=1
for AZ in $AZS; do
  if [ $i -gt 3 ]; then break; fi
  SUBNET_NAME="${VPC_NAME}-subnet-$i"
  SUBNET_CIDR="10.42.${i}.0/24"

  SUBNET_ID=$(aws ec2 describe-subnets \
    --filters Name=tag:Name,Values=$SUBNET_NAME Name=vpc-id,Values=$VPC_ID \
    --query 'Subnets[0].SubnetId' --output text --region $REGION 2>/dev/null)

  if [ "$SUBNET_ID" = "None" ] || [ -z "$SUBNET_ID" ]; then
    SUBNET_ID=$(aws ec2 create-subnet \
      --vpc-id $VPC_ID --cidr-block $SUBNET_CIDR \
      --availability-zone $AZ --region $REGION \
      --query 'Subnet.SubnetId' --output text)
    aws ec2 create-tags --resources $SUBNET_ID \
      --tags Key=Name,Value=$SUBNET_NAME Key=Project,Value=reliability-platform-v03 \
      --region $REGION
    # Auto-assign public IPs at the subnet level (belt-and-braces with assignPublicIp=ENABLED).
    aws ec2 modify-subnet-attribute --subnet-id $SUBNET_ID \
      --map-public-ip-on-launch --region $REGION
  fi
  echo "  Subnet $i ($AZ, $SUBNET_CIDR): $SUBNET_ID"

  if [ -z "$SUBNETS" ]; then SUBNETS="$SUBNET_ID"
  else SUBNETS="$SUBNETS,$SUBNET_ID"
  fi
  i=$((i + 1))
done

if [ -z "$SUBNETS" ]; then
  echo "ERROR: no subnets created. Cannot continue." >&2
  exit 1
fi
echo "Subnets: $SUBNETS"

echo '=== Step 4: Route table with default route to IGW ==='
RT_ID=$(aws ec2 describe-route-tables \
  --filters Name=vpc-id,Values=$VPC_ID Name=tag:Name,Values=${VPC_NAME}-rt \
  --query 'RouteTables[0].RouteTableId' \
  --output text --region $REGION 2>/dev/null)

if [ "$RT_ID" = "None" ] || [ -z "$RT_ID" ]; then
  RT_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --region $REGION \
    --query 'RouteTable.RouteTableId' --output text)
  aws ec2 create-tags --resources $RT_ID \
    --tags Key=Name,Value=${VPC_NAME}-rt Key=Project,Value=reliability-platform-v03 \
    --region $REGION
  aws ec2 create-route --route-table-id $RT_ID \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $IGW_ID --region $REGION > /dev/null
  echo "Created route table: $RT_ID"
else
  echo "Reusing route table: $RT_ID"
fi

# Associate every subnet with the route table (idempotent: skip if already associated).
for SUBNET_ID in $(echo $SUBNETS | tr ',' ' '); do
  ASSOC=$(aws ec2 describe-route-tables --route-table-ids $RT_ID \
    --query "RouteTables[0].Associations[?SubnetId=='$SUBNET_ID'].RouteTableAssociationId" \
    --output text --region $REGION 2>/dev/null)
  if [ -z "$ASSOC" ]; then
    aws ec2 associate-route-table --route-table-id $RT_ID \
      --subnet-id $SUBNET_ID --region $REGION > /dev/null 2>&1 || true
  fi
done
echo "Route table associated with all subnets."

echo '=== Step 5: Create ECS cluster ==='
aws ecs create-cluster --cluster-name $CLUSTER --region $REGION 2>/dev/null || true

echo '=== Step 6: Create security group ==='
SG_ID=$(aws ec2 describe-security-groups \
  --filters Name=group-name,Values=$SG_NAME Name=vpc-id,Values=$VPC_ID \
  --query 'SecurityGroups[0].GroupId' --output text --region $REGION 2>/dev/null)

if [ "$SG_ID" = "None" ] || [ -z "$SG_ID" ]; then
  SG_ID=$(aws ec2 create-security-group \
    --group-name $SG_NAME \
    --description 'V4 Platform SG' \
    --vpc-id $VPC_ID --region $REGION \
    --query 'GroupId' --output text)
  aws ec2 create-tags --resources $SG_ID \
    --tags Key=Name,Value=$SG_NAME Key=Project,Value=reliability-platform-v03 \
    --region $REGION
fi
echo "Security Group: $SG_ID"

for PORT in 80 3000 5000; do
  aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID --protocol tcp \
    --port $PORT --cidr 0.0.0.0/0 \
    --region $REGION 2>/dev/null || true
done

echo '=== Step 7: Create IAM Task Execution Role ==='
TRUST='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ecs-tasks.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

aws iam create-role \
  --role-name ecsExecRole-v03 \
  --assume-role-policy-document "$TRUST" 2>/dev/null || true

aws iam attach-role-policy \
  --role-name ecsExecRole-v03 \
  --policy-arn arn:aws:iam:aws:policy/service-role/AmazonECSTaskExecutionRolePolicy 2>/dev/null || true

EXEC_ROLE="arn:aws:iam:${ACCOUNT_ID}:role/ecsExecRole-v03"

echo '=== Step 8: Wait for IAM role to propagate ==='
for i in 1 2 3 4 5 6; do
  if aws iam get-role --role-name ecsExecRole-v03 \
       --query 'Role.Arn' --output text >/dev/null 2>&1; then
    sleep 10
    break
  fi
  sleep 5
done
echo "IAM role ready: $EXEC_ROLE"

echo '=== Step 9: Pre-create CloudWatch log groups ==='
# AmazonECSTaskExecutionRolePolicy grants CreateLogStream + PutLogEvents but
# NOT CreateLogGroup, so awslogs-create-group=true would fail the task at
# startup. Create the groups up front instead.
for SVC in flask-api node-api web-ui; do
  aws logs create-log-group --log-group-name "/ecs/v03/$SVC" \
    --region $REGION 2>/dev/null \
    && echo "  Created log group: /ecs/v03/$SVC" \
    || echo "  Log group /ecs/v03/$SVC already exists."
done

echo '=== Step 10: Register task definitions and create/update services ==='
for SVC in flask-api node-api web-ui; do
  PORT=5000
  [ "$SVC" = "node-api" ] && PORT=3000
  [ "$SVC" = "web-ui"   ] && PORT=80

  CONTAINER_DEF="[{\"name\":\"${SVC}\",\"image\":\"${ECR_BASE}/${SVC}:latest\",\
\"portMappings\":[{\"containerPort\":${PORT}}],\"essential\":true,\
\"logConfiguration\":{\"logDriver\":\"awslogs\",\
\"options\":{\"awslogs-group\":\"/ecs/v03/${SVC}\",\
\"awslogs-region\":\"${REGION}\",\"awslogs-stream-prefix\":\"ecs\"}}}]"

  echo "  [$SVC] Registering task definition..."
  if ! aws ecs register-task-definition \
       --family ${SVC}-v03 \
       --network-mode awsvpc \
       --requires-compatibilities FARGATE \
       --cpu 256 --memory 512 \
       --execution-role-arn $EXEC_ROLE \
       --container-definitions "$CONTAINER_DEF" \
       --region $REGION > /dev/null; then
    echo "  [$SVC] ERROR: task definition registration failed: skipping service."
    continue
  fi

  # Idempotent: create the service if missing, otherwise update it in place.
  EXISTING=$(aws ecs describe-services \
    --cluster $CLUSTER --services $SVC --region $REGION \
    --query 'services[?status==`ACTIVE`].serviceName' --output text 2>/dev/null || true)

  if [ -z "$EXISTING" ]; then
    echo "  [$SVC] Creating service..."
    aws ecs create-service \
      --cluster $CLUSTER \
      --service-name $SVC \
      --task-definition ${SVC}-v03 \
      --desired-count 1 \
      --launch-type FARGATE \
      --network-configuration \
      "awsvpcConfiguration={subnets=[${SUBNETS}],securityGroups=[${SG_ID}],assignPublicIp=ENABLED}" \
      --region $REGION > /dev/null \
      && echo "  [$SVC] Created on port $PORT" \
      || echo "  [$SVC] ERROR: create-service failed."
  else
    echo "  [$SVC] Service exists: updating to new task definition..."
    aws ecs update-service \
      --cluster $CLUSTER \
      --service $SVC \
      --task-definition ${SVC}-v03 \
      --desired-count 1 \
      --force-new-deployment \
      --region $REGION > /dev/null \
      && echo "  [$SVC] Updated on port $PORT" \
      || echo "  [$SVC] ERROR: update-service failed."
  fi
done

echo ''
echo '=== Step 11: Verify services ==='
aws ecs list-services --cluster $CLUSTER --region $REGION \
  --query 'serviceArns' --output table

echo ''
echo '=== Done! Wait ~90 seconds for tasks to reach RUNNING, then run get_public_ips.sh ==='
echo "    VPC ID:     $VPC_ID"
echo "    Subnets:    $SUBNETS"
echo "    SG:         $SG_ID"
echo "    Cluster:    $CLUSTER"
