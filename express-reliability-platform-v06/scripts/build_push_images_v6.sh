#!/bin/bash
###############################################################################
# Build and push the three service images to V6's ECR repos.
#
# V6 ships its own web-ui (Dockerfile + index.html under V6's apps/web-ui/).
# flask-api and node-api are unchanged from V5, so their sources are still
# read from V5's apps/. Override V5_APPS_SRC if you've copied those sources
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
V6_APPS_SRC="${V6_ROOT}/apps"
V5_APPS_SRC="${V5_APPS_SRC:-${V6_ROOT}/../express-reliability-platform-v05/apps}"

# Per-service source paths: web-ui from V6 (so V6's index.html actually ships),
# flask-api and node-api from V5 since those services are unchanged.
svc_src() {
  case "$1" in
    web-ui)            echo "${V6_APPS_SRC}/$1" ;;
    flask-api|node-api) echo "${V5_APPS_SRC}/$1" ;;
    *) echo "ERROR: unknown service $1" >&2; exit 1 ;;
  esac
}

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
echo "  ECR base:    ${ECR_BASE}"
echo "  V6 apps src: ${V6_APPS_SRC}  (web-ui)"
echo "  V5 apps src: ${V5_APPS_SRC}  (flask-api, node-api)"
echo "  tag:         ${TAG}"

# Fail fast with an actionable message. Most common cause: V5 directory was
# deleted (flask-api/node-api), or V6's web-ui/Dockerfile is missing.
for SVC in "${SERVICES[@]}"; do
  SRC="$(svc_src "${SVC}")"
  if [[ ! -f "${SRC}/Dockerfile" ]]; then
    echo "ERROR: ${SRC}/Dockerfile not found." >&2
    if [[ "${SVC}" == "web-ui" ]]; then
      echo "       V6's web-ui Dockerfile should live at ${V6_APPS_SRC}/web-ui/." >&2
    else
      echo "       Set V5_APPS_SRC=<path-to-v5-apps> and re-run." >&2
    fi
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
  SRC="$(svc_src "${SVC}")"
  echo "--- ${SVC}  (src: ${SRC}) ---"
  docker buildx build --platform linux/amd64 \
    -t "${ECR_BASE}/${SVC}:${TAG}" \
    --push \
    "${SRC}"
done

echo "=== Done. Pushed ${#SERVICES[@]} images to ${ECR_BASE} ==="
