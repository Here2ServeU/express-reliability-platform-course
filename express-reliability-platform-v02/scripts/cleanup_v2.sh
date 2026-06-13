#!/bin/bash
# cleanup_v2.sh: stop all V2 containers and clean Docker

echo 'Stopping V2 platform...'
docker compose down

echo 'Removing V2 images...'
docker rmi express-reliability-platform-v02-flask-api 2>/dev/null || true
docker rmi express-reliability-platform-v02-node-api 2>/dev/null || true
docker rmi express-reliability-platform-v02-web-ui 2>/dev/null || true

echo 'Pruning Docker build cache...'
docker builder prune -f

echo 'Verifying cleanup...'
RUNNING=$(docker ps --filter 'name=flask-api' --filter 'name=node-api' -q)
if [ -z "$RUNNING" ]; then
  echo 'CONFIRMED: No platform containers running.'
else
  echo "WARNING: Still running: $RUNNING"
fi

echo 'Cleanup complete.'
