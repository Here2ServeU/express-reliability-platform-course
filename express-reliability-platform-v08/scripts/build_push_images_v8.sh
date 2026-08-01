#!/bin/bash
# =============================================================================
# build_push_images_v8.sh
# Builds flask-api, node-api, and web-ui from this V8 project for linux/amd64
# and pushes all three to ECR.
#
# CHANGED FROM V7: every image is pushed under TWO tags.
#
#   <short-git-sha>  the immutable one. This is what GitOps deploys, because
#                    a tag that never moves is the only kind that makes
#                    "what is running in prod" a question Git can answer.
#
#   v8               a mutable convenience tag, so `helm install` still works
#                    without GitOps and the very first deploy has something
#                    to pull. Deliberately NOT `:latest` — the
#                    no-latest-tag Gatekeeper constraint denies that at
#                    admission, which is the point of the policy.
#
# USAGE:
#   ./scripts/build_push_images_v8.sh
#   IMAGE_TAG=rc-3 ./scripts/build_push_images_v8.sh    # override the sha tag
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

# ── Step 4: work out the immutable tag ───────────────────────────────────────
# Short git SHA of the current commit. If the working tree is dirty the SHA
# does not describe what is actually being built, so say so — a tag that
# lies about its contents is worse than no tag.
IMAGE_TAG="${IMAGE_TAG:-$(git rev-parse --short HEAD 2>/dev/null || echo 'nogit')}"

if [[ "${IMAGE_TAG}" == "nogit" ]]; then
  echo ""
  echo "WARN: not a git repo — falling back to the mutable 'v8' tag only."
  echo "      GitOps promotion needs an immutable tag; run this from a clone."
  IMAGE_TAG="v8"
elif [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
  echo ""
  echo "WARN: working tree has uncommitted changes."
  echo "      Tagging as ${IMAGE_TAG}, but that commit does NOT contain what"
  echo "      is being built. Commit first if you plan to promote this tag."
fi

# ── Step 5: build and push all three services ────────────────────────────────
echo ""
echo "=== Building and pushing all three images ==="
echo "    immutable tag: ${IMAGE_TAG}"
echo "    mutable tag:   v8"
for SVC in flask-api node-api web-ui; do
  echo ""
  echo "--- Building: ${SVC} ---"
  # One build, two tags, one push: buildx pushes both refs from the same
  # image, so the sha tag and the v8 tag are guaranteed to be identical
  # bytes rather than two builds that happen to look alike.
  docker buildx build \
    --platform linux/amd64 \
    --tag "${ECR_BASE}/${SVC}:${IMAGE_TAG}" \
    --tag "${ECR_BASE}/${SVC}:v8" \
    --push \
    "${PROJECT_ROOT}/apps/${SVC}"
done

echo ""
echo "=== All three images are in ECR. ==="
echo ""
echo "  flask-api : ${ECR_BASE}/flask-api:${IMAGE_TAG}"
echo "  node-api  : ${ECR_BASE}/node-api:${IMAGE_TAG}"
echo "  web-ui    : ${ECR_BASE}/web-ui:${IMAGE_TAG}"
echo ""
echo "To deploy these through GitOps, point Git at the immutable tag:"
echo ""
echo "  ./scripts/promote_image_v8.sh ${IMAGE_TAG} dev"
echo "  git add gitops/apps/dev && git commit -m 'deploy(dev): ${IMAGE_TAG}' && git push"
echo ""
