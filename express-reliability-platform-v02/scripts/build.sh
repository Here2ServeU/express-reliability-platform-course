#!/usr/bin/env bash
# Build the V2 container image.
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-express-reliability-v02}"
IMAGE_TAG="${IMAGE_TAG:-local}"

cd "$(dirname "$0")/.."

echo "Building ${IMAGE_NAME}:${IMAGE_TAG} for linux/amd64..."
docker build --platform linux/amd64 -t "${IMAGE_NAME}:${IMAGE_TAG}" .

echo
echo "Image built:"
docker images "${IMAGE_NAME}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
