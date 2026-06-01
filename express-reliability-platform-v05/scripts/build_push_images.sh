#!/bin/bash
###############################################################################
# Option 1: Build, tag, and push images via bash + docker buildx.
#
# Standalone version of the image pipeline. Use this when the platform is
# already deployed and you only changed application code, so you don't need
# to re-run terraform. For the full deploy use scripts/tf_deploy.sh.
#
# For Option 2 (Terraform-driven build/tag/push), see terraform/platform/images.tf
# or run `IMAGE_BUILD_MODE=terraform ./scripts/tf_deploy.sh`.
###############################################################################
set -euo pipefail

REGION="us-east-1"
PROJECT="reliability-platform"
CLUSTER="reliability-platform-cluster"
SERVICES=(flask-api node-api web-ui)
TAG="${IMAGE_TAG:-latest}"
FORCE_DEPLOY="${FORCE_DEPLOY:-true}"

echo '=== Step 1: Resolve AWS account and ECR base URI ==='
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_BASE="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${PROJECT}"

echo "  account id: ${ACCOUNT_ID}"
echo "  ECR base:   ${ECR_BASE}"
echo "  image tag:  ${TAG}"

echo '=== Step 2: Authenticate Docker to ECR ==='
# The login token expires after 12 hours. Re-run this script (or just this step)
# if a later push fails with "no basic auth credentials".
aws ecr get-login-password --region "${REGION}" | \
  docker login --username AWS --password-stdin \
  "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo '=== Step 3: Build, tag, and push each service image ==='
# ECS Fargate runs linux/amd64 by default. On Apple Silicon (M1/M2/M3) Macs,
# `docker build` would produce linux/arm64, which Fargate cannot pull
# you would see "image Manifest does not contain descriptor matching
# platform 'linux/amd64'". `buildx --platform linux/amd64 --push` builds
# for the right architecture and ships straight to ECR in one step.
for SVC in "${SERVICES[@]}"; do
  echo "--- ${SVC} ---"
  docker buildx build --platform linux/amd64 \
    -t "${ECR_BASE}/${SVC}:${TAG}" \
    --push \
    "./apps/${SVC}"
done

if [[ "${FORCE_DEPLOY}" == "true" ]]; then
  echo '=== Step 4: Force ECS to redeploy with the new images ==='
  # Fargate caches :latest. Without --force-new-deployment, overwriting the
  # tag in ECR does not cause running tasks to be replaced.
  if aws ecs describe-clusters \
       --clusters "${CLUSTER}" \
       --region "${REGION}" \
       --query 'clusters[0].status' \
       --output text 2>/dev/null | grep -q ACTIVE; then
    for SVC in "${SERVICES[@]}"; do
      echo "  redeploying ${SVC}"
      aws ecs update-service \
        --cluster "${CLUSTER}" \
        --service "${SVC}" \
        --force-new-deployment \
        --region "${REGION}" >/dev/null
    done
    echo 'Wait 1-3 minutes for ECS to drain old tasks and register the new ones.'
  else
    echo "  cluster ${CLUSTER} not found or not ACTIVE: skipping forced redeploy."
    echo "  Run scripts/tf_deploy.sh first to create the platform."
  fi
else
  echo '=== Step 4: Skipping ECS redeploy (FORCE_DEPLOY=false) ==='
fi
