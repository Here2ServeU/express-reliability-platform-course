#!/bin/bash
###############################################################################
# Build and push the three service images to V6's ECR repos.
#
# V6 only carries web-ui/index.html — the flask-api / node-api Dockerfiles
# and source live in V5's apps/. APPS_SRC defaults to ../express-reliability-
# platform-v05/apps for that reason; override it if you've copied sources
# elsewhere.
#
# Usable standalone (after bootstrap apply has created the ECR repos) for
# app-only redeploys, or invoked by tf_deploy_v6.sh as part of the full deploy.
###############################################################################
set -euo pipefail

REGION="${REGION:-us-east-1}"
PROJECT="${PROJECT:-reliability-platform}"
SERVICES=(flask-api node-api web-ui)
TAG="${IMAGE_TAG:-latest}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
V6_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
APPS_SRC="${APPS_SRC:-${V6_ROOT}/../express-reliability-platform-v05/apps}"

echo "=== Resolving ECR base URI ==="
# Prefer the bootstrap output so this script and tf_deploy_v6.sh agree on the
# URI even if someone overrides project_name in bootstrap. Fall back to STS so
# the script still works if invoked from a clone of the repo where bootstrap
# state isn't local (e.g. a fresh checkout pointing at a remote backend).
if ECR_BASE=$(terraform -chdir="${V6_ROOT}/platform/terraform/bootstrap" \
                output -raw ecr_base_uri 2>/dev/null); then
  echo "  source: bootstrap output"
else
  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  ECR_BASE="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${PROJECT}"
  echo "  source: aws sts (bootstrap output unavailable)"
fi
echo "  ECR base: ${ECR_BASE}"
echo "  apps src: ${APPS_SRC}"
echo "  tag:      ${TAG}"

# Fail fast with an actionable message: the most common cause of a missing
# Dockerfile here is "I deleted V5's directory" or "I cloned only V6".
for SVC in "${SERVICES[@]}"; do
  if [[ ! -f "${APPS_SRC}/${SVC}/Dockerfile" ]]; then
    echo "ERROR: ${APPS_SRC}/${SVC}/Dockerfile not found." >&2
    echo "       Set APPS_SRC=<path-to-apps-with-Dockerfiles> and re-run." >&2
    exit 1
  fi
done

echo "=== Authenticating Docker to ECR ==="
# Token expires after 12h. Re-run this script (or just this step) if a later
# push fails with "no basic auth credentials".
aws ecr get-login-password --region "${REGION}" | \
  docker login --username AWS --password-stdin \
  "${ECR_BASE%/*}"

echo "=== Building and pushing ==="
# EKS nodes (and ECS Fargate) run linux/amd64. On Apple Silicon a plain
# `docker build` produces linux/arm64, which the cluster cannot pull —
# you would see "image Manifest does not contain descriptor matching platform
# 'linux/amd64'". buildx --platform linux/amd64 --push handles both archs.
for SVC in "${SERVICES[@]}"; do
  echo "--- ${SVC} ---"
  docker buildx build --platform linux/amd64 \
    -t "${ECR_BASE}/${SVC}:${TAG}" \
    --push \
    "${APPS_SRC}/${SVC}"
done

echo "=== Done. Pushed ${#SERVICES[@]} images to ${ECR_BASE} ==="
