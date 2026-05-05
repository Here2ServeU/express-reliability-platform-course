#!/bin/bash
set -euo pipefail

# IMAGE_BUILD_MODE controls how images get into ECR:
#   bash      — Option 1 (default): this script logs into ECR and runs
#               docker buildx for each service before applying the platform.
#   terraform — Option 2: skip the bash build/push and let Terraform do it
#               via the kreuzwerker/docker provider (terraform/platform/images.tf).
#               The platform apply gets `-var build_images=true`.
IMAGE_BUILD_MODE="${IMAGE_BUILD_MODE:-bash}"

REGION="us-east-1"
PROJECT="reliability-platform"
SERVICES=(flask-api node-api web-ui)

echo "=== Mode: ${IMAGE_BUILD_MODE} ==="

echo '=== Step 1: Apply bootstrap (S3 state bucket + DynamoDB lock table) ==='
terraform -chdir=terraform/bootstrap init -input=false
terraform -chdir=terraform/bootstrap apply -auto-approve

echo '=== Step 2: Read bootstrap outputs and feed them into the platform stack ==='
STATE_BUCKET=$(terraform -chdir=terraform/bootstrap output -raw state_bucket)
ACCOUNT_ID=$(terraform -chdir=terraform/bootstrap output -raw account_id)
ECR_BASE="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${PROJECT}"

echo "  state bucket: ${STATE_BUCKET}"
echo "  account id:   ${ACCOUNT_ID}"

echo '=== Step 3: Initialize platform Terraform against the bootstrap backend ==='
terraform -chdir=terraform/platform init \
  -reconfigure \
  -input=false \
  -backend-config="bucket=${STATE_BUCKET}" \
  -backend-config="region=${REGION}" \
  -backend-config="dynamodb_table=terraform-state-lock" \
  -backend-config="key=platform/v5/terraform.tfstate"

echo '=== Step 4: Create ECR repos first (so we have somewhere to push images) ==='
terraform -chdir=terraform/platform apply -auto-approve \
  -target=aws_ecr_repository.services

if [[ "${IMAGE_BUILD_MODE}" == "bash" ]]; then
  echo '=== Step 5 (Option 1 / bash): Build, tag, and push images via docker buildx ==='
  # ECS Fargate runs linux/amd64 by default. On Apple Silicon (M1/M2/M3) Macs,
  # `docker build` produces linux/arm64 images, which Fargate cannot pull —
  # you would see "image Manifest does not contain descriptor matching
  # platform 'linux/amd64'". We force the target platform here so the script
  # works on both Intel and Apple Silicon hosts.
  aws ecr get-login-password --region "${REGION}" | \
    docker login --username AWS --password-stdin \
    "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

  for SVC in "${SERVICES[@]}"; do
    docker buildx build --platform linux/amd64 \
      -t "${ECR_BASE}/${SVC}:latest" \
      --push \
      "./apps/${SVC}"
  done

  echo '=== Step 6: Apply the full platform (ECS, ALB, IAM, networking) ==='
  terraform -chdir=terraform/platform apply -auto-approve
elif [[ "${IMAGE_BUILD_MODE}" == "terraform" ]]; then
  echo '=== Step 5 (Option 2 / terraform): images will be built and pushed by Terraform ==='
  echo '  See terraform/platform/images.tf — docker_image + docker_registry_image resources.'

  echo '=== Step 6: Apply the full platform with build_images=true ==='
  terraform -chdir=terraform/platform apply -auto-approve \
    -var build_images=true
else
  echo "ERROR: IMAGE_BUILD_MODE must be 'bash' or 'terraform' (got '${IMAGE_BUILD_MODE}')." >&2
  exit 1
fi

echo '=== Step 7: Platform URL ==='
terraform -chdir=terraform/platform output alb_dns_name
echo 'Wait 3-5 minutes for tasks to start and register with the ALB.'
