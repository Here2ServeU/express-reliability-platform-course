#!/bin/bash
# Build and push all three service images to Artifact Registry.
# Images are tagged with the git commit SHA (never :latest), so every
# deploy is traceable and Gatekeeper's no-latest-tag policy passes.
# Prints the tag on the last line for deploy_capstone.sh.
set -euo pipefail

REGISTRY=$(terraform -chdir=platform/terraform/bootstrap output -raw registry)
TAG="${TAG:-$(git rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)}"

gcloud auth configure-docker "$(echo "$REGISTRY" | cut -d/ -f1)" --quiet >&2

for SVC in flask-api node-api web-ui; do
  echo "Building and pushing: ${SVC}:${TAG}" >&2
  docker buildx build --platform linux/amd64 \
    -t "${REGISTRY}/${SVC}:${TAG}" --push "./apps/${SVC}" >&2
done

echo "All three images pushed to Artifact Registry." >&2
echo "$TAG"
