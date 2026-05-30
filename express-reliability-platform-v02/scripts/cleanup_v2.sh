#!/usr/bin/env bash
# Stop the V2 container and remove its image.
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-express-reliability-v02}"
IMAGE_TAG="${IMAGE_TAG:-local}"
CONTAINER_NAME="${CONTAINER_NAME:-erp-v02}"

if docker ps -aq --filter "name=^${CONTAINER_NAME}$" | grep -q .; then
  echo "Removing container '${CONTAINER_NAME}'..."
  docker rm -f "${CONTAINER_NAME}" >/dev/null
fi

if docker images -q "${IMAGE_NAME}:${IMAGE_TAG}" | grep -q .; then
  echo "Removing image '${IMAGE_NAME}:${IMAGE_TAG}'..."
  docker rmi "${IMAGE_NAME}:${IMAGE_TAG}" >/dev/null
fi

echo "V2 cleanup complete."
