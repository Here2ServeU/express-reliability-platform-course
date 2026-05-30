#!/usr/bin/env bash
# Run the V2 container locally.
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-express-reliability-v02}"
IMAGE_TAG="${IMAGE_TAG:-local}"
CONTAINER_NAME="${CONTAINER_NAME:-erp-v02}"
HOST_PORT="${HOST_PORT:-3000}"

# Stop any previous instance with the same name.
if docker ps -aq --filter "name=^${CONTAINER_NAME}$" | grep -q .; then
  echo "Removing existing container '${CONTAINER_NAME}'..."
  docker rm -f "${CONTAINER_NAME}" >/dev/null
fi

echo "Starting ${CONTAINER_NAME} from ${IMAGE_NAME}:${IMAGE_TAG} on http://localhost:${HOST_PORT} ..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  -p "${HOST_PORT}:3000" \
  --restart unless-stopped \
  "${IMAGE_NAME}:${IMAGE_TAG}"

echo
echo "Container started. Useful follow-up commands:"
echo "  docker logs -f ${CONTAINER_NAME}"
echo "  curl http://localhost:${HOST_PORT}/health"
echo "  docker stop ${CONTAINER_NAME}"
