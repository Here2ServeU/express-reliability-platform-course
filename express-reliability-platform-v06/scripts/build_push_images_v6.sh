#!/bin/bash
# =============================================================================
# build_push_images_v6.sh
# Builds flask-api, node-api, and web-ui from this V6 project for linux/amd64
# and pushes all three to ECR.
#
# USAGE:
#   ./scripts/build_push_images_v6.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ── Step 1: validate all three Dockerfiles exist ─────────────────────────────
for SVC in flask-api node-api web-ui; do
  if [[ ! -f "${PROJECT_ROOT}/apps/${SVC}/Dockerfile" ]]; then
    echo ""
    echo "ERROR: apps/${SVC}/Dockerfile not found."
    echo ""
    echo "  Expected: ${PROJECT_ROOT}/apps/${SVC}/Dockerfile"
    echo ""
    echo "  Make sure all three service folders are inside this project:"
    echo "    apps/flask-api/Dockerfile"
    echo "    apps/node-api/Dockerfile"
    echo "    apps/web-ui/Dockerfile"
    echo ""
    exit 1
  fi
done

# ── Step 2: get ECR base URL from bootstrap output ───────────────────────────
echo ""
echo "=== Reading ECR base URL from bootstrap Terraform output ==="
ECR_BASE=$(terraform -chdir="${PROJECT_ROOT}/platform/terraform/bootstrap" output -raw ecr_base_uri)

if [[ -z "${ECR_BASE}" ]]; then
  echo ""
  echo "ERROR: Could not read ecr_base_uri from bootstrap Terraform output."
  echo ""
  echo "  Make sure bootstrap has been applied first:"
  echo "    terraform -chdir=platform/terraform/bootstrap init"
  echo "    terraform -chdir=platform/terraform/bootstrap apply -auto-approve"
  echo ""
  exit 1
fi

echo "ECR base: ${ECR_BASE}"

# ── Step 3: ECR login ────────────────────────────────────────────────────────
echo ""
echo "=== Logging in to ECR ==="
ECR_REGISTRY="$(echo "${ECR_BASE}" | cut -d/ -f1)"
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin "${ECR_REGISTRY}"

# ── Step 4: build and push all three services ─────────────────────────────────
echo ""
echo "=== Building and pushing all three images ==="
for SVC in flask-api node-api web-ui; do
  echo ""
  echo "--- Building: ${SVC} ---"
  docker buildx build \
    --platform linux/amd64 \
    --tag "${ECR_BASE}/${SVC}:latest" \
    --push \
    "${PROJECT_ROOT}/apps/${SVC}"
done

echo ""
echo "=== All three images are in ECR. Ready to deploy to Kubernetes. ==="
echo ""
echo "  flask-api : ${ECR_BASE}/flask-api:latest"
echo "  node-api  : ${ECR_BASE}/node-api:latest"
echo "  web-ui    : ${ECR_BASE}/web-ui:latest"
echo ""
