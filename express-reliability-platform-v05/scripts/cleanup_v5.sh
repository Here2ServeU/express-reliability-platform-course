#!/bin/bash
# Full V5 teardown: stops the local Compose stack, destroys the platform
# stack on AWS (ECS, ALB, ECR, IAM, networking), and destroys the bootstrap
# stack (S3 state bucket + DynamoDB lock table).
#
# Note: no `set -e` — we want each step to keep going even if a previous one
# partially failed, so a half-cleaned-up environment can be finished off.

REGION="us-east-1"

echo '=== V5 Full Cleanup ==='
echo 'This will stop the local stack AND destroy ALL V5 AWS resources,'
echo 'including the Terraform state backend and any ECR repositories'
echo "named reliability-platform/* in ${REGION}."
echo
echo 'NOTE: V4 and V5 share the same project name (reliability-platform),'
echo '      so this also removes any ECR repos a parallel V4 deploy created.'
echo

echo '=== Step 0: Local Docker cleanup (stack, volumes, orphans) ==='
# `down -v` removes named volumes declared in docker-compose.yml (e.g. grafana-data)
# `--remove-orphans` removes containers from prior compose configs that no longer exist
docker compose down -v --remove-orphans 2>/dev/null
# Belt-and-braces — explicitly drop the grafana volume in case it lingered.
docker volume rm express-reliability-platform-v05_grafana-data 2>/dev/null
docker volume ls | grep grafana \
  && echo '  (grafana volume still present — leftover from a different project)' \
  || echo '  grafana volume gone'

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
    -backend-config="key=platform/v5/terraform.tfstate"

  echo '=== Step 3: Destroy platform (ECS, ALB, ECR, IAM, networking) ==='
  # ECR repos have force_delete=true, so they tear down even with images present.
  terraform -chdir=terraform/platform destroy -auto-approve
fi

echo '=== Step 3b: Sweep any leftover ECR repositories (defensive) ==='
# Terraform destroy normally removes ECR, but if state drifted or destroy
# was interrupted, repos can survive. Force-delete any remaining
# reliability-platform/* repos so cleanup is idempotent.
LEFTOVER_REPOS=$(aws ecr describe-repositories --region "$REGION" \
  --query "repositories[?starts_with(repositoryName, 'reliability-platform/')].repositoryName" \
  --output text 2>/dev/null)
if [ -n "$LEFTOVER_REPOS" ]; then
  for REPO in $LEFTOVER_REPOS; do
    echo "  deleting ECR repo: $REPO"
    aws ecr delete-repository --repository-name "$REPO" \
      --region "$REGION" --force >/dev/null 2>&1
  done
else
  echo '  no leftover reliability-platform/* repositories found'
fi

echo '=== Step 4: Remove local Docker images (built + pulled) ==='
# Locally-built service images
docker rmi flask-api:latest node-api:latest web-ui:latest 2>/dev/null

# ECR-tagged copies of the same images created by tf_deploy.sh
# (e.g. <account>.dkr.ecr.<region>.amazonaws.com/reliability-platform/flask-api:latest)
if [ -n "$ACCOUNT_ID" ] && [ "$ACCOUNT_ID" != "null" ]; then
  ECR_BASE="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/reliability-platform"
  for SVC in flask-api node-api web-ui; do
    docker rmi "${ECR_BASE}/${SVC}:latest" 2>/dev/null
  done
fi

# Pulled monitoring images from the compose stack
docker rmi prom/prometheus:latest \
           grafana/grafana:latest \
           prom/alertmanager:latest 2>/dev/null

# Catch-all: drop any image tagged with our project prefix that survived
docker images --format '{{.Repository}}:{{.Tag}}' \
  | grep -E '(^reliability-platform|/reliability-platform/)' \
  | xargs -r docker rmi 2>/dev/null

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

echo '=== Step 8: Remove local Terraform artifacts (.terraform/, lock files, local state) ==='
# These files survive `terraform destroy` and would otherwise contain stale
# references to destroyed resources. Wiping them guarantees the next
# `tf_deploy.sh` run starts from a clean slate.
for DIR in terraform/bootstrap terraform/platform; do
  rm -rf "$DIR/.terraform" \
         "$DIR/.terraform.lock.hcl" \
         "$DIR/terraform.tfstate" \
         "$DIR/terraform.tfstate.backup" \
         "$DIR/tfplan" 2>/dev/null
  echo "  cleaned: $DIR"
done

echo
echo '=== Done! Full V5 teardown complete. ==='
echo 'To redeploy V5, run: ./scripts/tf_deploy.sh'
