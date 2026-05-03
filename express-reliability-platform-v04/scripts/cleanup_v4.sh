#!/bin/bash
# Full V4 teardown: destroys the platform stack (ECS, ALB, ECR, IAM, networking)
# AND the bootstrap stack (S3 state bucket + DynamoDB lock table).
#
# Note: no `set -e` — we want each step to keep going even if a previous one
# partially failed, so a half-cleaned-up environment can be finished off.

REGION="us-east-1"

echo '=== V4 Full Cleanup ==='
echo 'This will destroy ALL V4 AWS resources including the Terraform state backend.'
echo

echo '=== Step 1: Read bootstrap outputs (need state-bucket name to init platform) ==='
STATE_BUCKET=$(terraform -chdir=terraform/bootstrap output -raw state_bucket 2>/dev/null)
ACCOUNT_ID=$(terraform -chdir=terraform/bootstrap output -raw account_id 2>/dev/null)

if [ -z "$STATE_BUCKET" ] || [ "$STATE_BUCKET" = "null" ]; then
  echo 'WARNING: no bootstrap state file found locally.'
  echo '         Skipping platform destroy. If platform resources still exist,'
  echo '         delete them by hand from the AWS console.'
  PLATFORM_SKIP=1
else
  echo "  state bucket: ${STATE_BUCKET}"
  echo "  account id:   ${ACCOUNT_ID}"
fi

if [ -z "$PLATFORM_SKIP" ]; then
  echo '=== Step 2: Re-init platform Terraform against the bootstrap backend ==='
  terraform -chdir=terraform/platform init \
    -reconfigure -input=false \
    -backend-config="bucket=${STATE_BUCKET}" \
    -backend-config="region=${REGION}" \
    -backend-config="dynamodb_table=terraform-state-lock" \
    -backend-config="key=platform/v4/terraform.tfstate"

  echo '=== Step 3: Destroy platform (ECS, ALB, ECR, IAM, networking) ==='
  # ECR repos have force_delete=true, so they tear down even with images present.
  terraform -chdir=terraform/platform destroy -auto-approve
fi

echo '=== Step 4: Remove local Docker images and prune ==='
docker rmi flask-api:latest node-api:latest web-ui:latest 2>/dev/null
docker system prune -f

if [ -n "$STATE_BUCKET" ] && [ "$STATE_BUCKET" != "null" ]; then
  echo "=== Step 5: Empty state bucket s3://${STATE_BUCKET} (all versions + delete markers) ==="
  # The state bucket has versioning enabled. terraform destroy on a non-empty
  # versioned bucket fails, so we empty every version and delete-marker first.

  VERSIONS=$(aws s3api list-object-versions \
    --bucket "$STATE_BUCKET" \
    --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
    --output json 2>/dev/null)
  if [ -n "$VERSIONS" ] && [ "$VERSIONS" != "null" ] && \
     [ "$(echo "$VERSIONS" | grep -o '"Key"' | wc -l)" -gt 0 ]; then
    aws s3api delete-objects --bucket "$STATE_BUCKET" --delete "$VERSIONS" >/dev/null
    echo '  deleted all object versions'
  fi

  MARKERS=$(aws s3api list-object-versions \
    --bucket "$STATE_BUCKET" \
    --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' \
    --output json 2>/dev/null)
  if [ -n "$MARKERS" ] && [ "$MARKERS" != "null" ] && \
     [ "$(echo "$MARKERS" | grep -o '"Key"' | wc -l)" -gt 0 ]; then
    aws s3api delete-objects --bucket "$STATE_BUCKET" --delete "$MARKERS" >/dev/null
    echo '  deleted all delete markers'
  fi
fi

echo '=== Step 6: Destroy bootstrap (S3 state bucket + DynamoDB lock table) ==='
terraform -chdir=terraform/bootstrap destroy -auto-approve

echo '=== Step 7: Verify cleanup ==='
echo '--- ECS clusters (should not include reliability-platform-cluster) ---'
aws ecs list-clusters --region "$REGION" --query 'clusterArns' --output text
echo '--- ALBs (should not include reliability-platform-alb) ---'
aws elbv2 describe-load-balancers --region "$REGION" \
  --query 'LoadBalancers[*].LoadBalancerName' --output text 2>/dev/null
echo '--- ECR repos (should not include reliability-platform/*) ---'
aws ecr describe-repositories --region "$REGION" \
  --query 'repositories[].repositoryName' --output text 2>/dev/null
echo '--- State buckets (should not include reliability-platform-tfstate-*) ---'
aws s3 ls 2>/dev/null | grep reliability-platform-tfstate || echo '  none'
echo '--- DynamoDB lock table (should not exist) ---'
aws dynamodb describe-table --table-name terraform-state-lock --region "$REGION" \
  --query 'Table.TableStatus' --output text 2>/dev/null || echo '  not found'

echo
echo '=== Done! Full V4 teardown complete. ==='
echo 'To redeploy V4, run: ./scripts/tf_deploy.sh'
