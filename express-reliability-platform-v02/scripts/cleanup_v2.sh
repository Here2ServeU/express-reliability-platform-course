#!/bin/bash
set -e
echo '================================================'
echo '  Version 2 Cleanup'
echo '================================================'

echo 'Step 1: Stop and remove all containers and network...'
docker compose down
echo '  Containers stopped and removed.'

echo 'Step 2: Remove built images...'
docker rmi express-reliability-platform-v02-flask-api 2>/dev/null || true
docker rmi express-reliability-platform-v02-node-api  2>/dev/null || true
docker rmi express-reliability-platform-v02-web-ui    2>/dev/null || true
echo '  Images removed.'

echo 'Step 3: Prune unused Docker build cache...'
docker builder prune -f
echo '  Build cache cleared.'

echo 'Step 4: Verify cleanup...'
RUNNING=$(docker ps --filter 'name=flask-api' --filter 'name=node-api' --filter 'name=web-ui' -q)
if [ -z "$RUNNING" ]; then
  echo '  CONFIRMED: No platform containers running.'
else
  echo "  WARNING: Still running: $RUNNING"
fi

echo '================================================'
echo '  Cleanup Complete!'
echo '  Next: Version 3 deploys this to AWS.'
echo '================================================'
