#!/bin/bash
###############################################################################
# Build and push the three service images to V7's ECR repos.
#
# V7 ships ALL service source — flask-api, node-api, web-ui — in this repo's
# apps/ directory. No cross-repo dependencies.
#
# Usable standalone (after bootstrap apply has created the ECR repos) for
# app-only redeploys, or invoked by tf_deploy_v7.sh as part of the full
# bootstrap → push → shared → live → apps flow.
#
# CI also pushes images via .github/workflows/deploy.yml on any push that
# changes apps/ — this script is for local iteration without committing.
###############################################################################
set -euo pipefail

REGION="${REGION:-us-east-1}"
PROJECT="${PROJECT:-reliability-platform}"
SERVICES=(flask-api node-api web-ui)
TAG="${IMAGE_TAG:-latest}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
V7_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=== Resolving ECR base URI ==="
# Prefer the bootstrap output so this script and tf_deploy_v7.sh agree on the
# URI even if someone overrides project_name in bootstrap. Fall back to STS so
# the script still works if invoked from a clone where bootstrap state isn't
# local (e.g. CI starting from a fresh checkout).
if ECR_BASE=$(terraform -chdir="${V7_ROOT}/terraform/bootstrap" \
                output -raw ecr_base_uri 2>/dev/null); then
  echo "  source: bootstrap output"
else
  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  ECR_BASE="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${PROJECT}"
  echo "  source: aws sts (bootstrap output unavailable)"
fi
echo "  ECR base: ${ECR_BASE}"
echo "  tag:      ${TAG}"

# Fail fast with an actionable message if a Dockerfile is missing — most
# common cause is a partial clone or a deleted apps/ subdirectory.
for SVC in "${SERVICES[@]}"; do
  CTX="${V7_ROOT}/apps/${SVC}"
  if [[ ! -f "${CTX}/Dockerfile" ]]; then
    echo "ERROR: ${CTX}/Dockerfile not found." >&2
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
# EKS nodes run linux/amd64. On Apple Silicon a plain `docker build` produces
# linux/arm64 — the cluster cannot pull it and every pod lands in
# ImagePullBackOff with "image manifest does not contain descriptor matching
# platform 'linux/amd64'". buildx --platform linux/amd64 --push fixes both.
for SVC in "${SERVICES[@]}"; do
  CTX="${V7_ROOT}/apps/${SVC}"
  echo "--- ${SVC} (context: ${CTX}) ---"
  docker buildx build --platform linux/amd64 \
    -t "${ECR_BASE}/${SVC}:${TAG}" \
    --push \
    "${CTX}"
done

echo "=== Done. Pushed ${#SERVICES[@]} images to ${ECR_BASE} ==="
