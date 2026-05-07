#!/bin/bash
###############################################################################
# Build and push the three service images to V7's ECR repos.
#
# V7 only ships web-ui/index.html. The flask-api / node-api Dockerfiles and
# source live in V5's apps/ directory — APPS_SRC defaults to
# ../express-reliability-platform-v05/apps. Override with APPS_SRC=<path>
# if your sources live elsewhere.
#
# Usable standalone (after bootstrap apply has created the ECR repos) for
# app-only redeploys, or invoked by tf_deploy_v7.sh as part of the full
# bootstrap → push → shared → live → apps flow.
###############################################################################
set -euo pipefail

REGION="${REGION:-us-east-1}"
PROJECT="${PROJECT:-reliability-platform}"
SERVICES=(flask-api node-api web-ui)
TAG="${IMAGE_TAG:-latest}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
V7_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
APPS_SRC="${APPS_SRC:-${V7_ROOT}/../express-reliability-platform-v05/apps}"

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
echo "  apps src: ${APPS_SRC}"
echo "  tag:      ${TAG}"

# Resolve the build context for each service.
#
# flask-api / node-api: source still lives in V5's apps/ — V7 does not ship
# Python or Node application code, only infrastructure changes.
#
# web-ui: V7 ships its OWN apps/web-ui/ with a V7-specific index.html and
# Dockerfile. Pulling web-ui from V5 here would silently deploy V5's UI on
# the V7 cluster (the bug that hid V7's content behind V5's nginx). Always
# build web-ui from this repo's apps/web-ui.
context_for() {
  local svc="$1"
  if [[ "$svc" == "web-ui" ]]; then
    echo "${V7_ROOT}/apps/web-ui"
  else
    echo "${APPS_SRC}/${svc}"
  fi
}

# Fail fast with an actionable message: the most common cause of a missing
# Dockerfile here is "I deleted V5's directory" or "I cloned only V7".
for SVC in "${SERVICES[@]}"; do
  CTX=$(context_for "${SVC}")
  if [[ ! -f "${CTX}/Dockerfile" ]]; then
    echo "ERROR: ${CTX}/Dockerfile not found." >&2
    if [[ "${SVC}" != "web-ui" ]]; then
      echo "       Set APPS_SRC=<path-to-apps-with-Dockerfiles> and re-run." >&2
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
# EKS nodes run linux/amd64. On Apple Silicon a plain `docker build` produces
# linux/arm64 — the cluster cannot pull it and every pod lands in
# ImagePullBackOff with "image manifest does not contain descriptor matching
# platform 'linux/amd64'". buildx --platform linux/amd64 --push fixes both.
for SVC in "${SERVICES[@]}"; do
  CTX=$(context_for "${SVC}")
  echo "--- ${SVC} (context: ${CTX}) ---"
  docker buildx build --platform linux/amd64 \
    -t "${ECR_BASE}/${SVC}:${TAG}" \
    --push \
    "${CTX}"
done

echo "=== Done. Pushed ${#SERVICES[@]} images to ${ECR_BASE} ==="
