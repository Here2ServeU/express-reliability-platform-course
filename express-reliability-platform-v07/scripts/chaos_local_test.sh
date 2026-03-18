#!/usr/bin/env bash
set -euo pipefail

# Local chaos test helper for V7.
# Run from v07 directory after your local stack is up.

TARGET_CONTAINER=${1:-node-api}
TEST_SECONDS=${2:-30}

printf "Running local chaos test against container: %s\n" "$TARGET_CONTAINER"
printf "Test duration: %s seconds\n" "$TEST_SECONDS"

printf "Step 1: verify container is running...\n"
docker ps --format '{{.Names}}' | grep -q "^${TARGET_CONTAINER}$"

printf "Step 2: inject CPU stress in target container...\n"
docker exec "$TARGET_CONTAINER" sh -lc "timeout ${TEST_SECONDS} sh -c 'yes > /dev/null'" || true

printf "Step 3: check service health endpoint...\n"
curl -fsS http://localhost:8080/api/health > /dev/null

printf "Local chaos test complete. Validate SLO/SLI dashboards and logs now.\n"
