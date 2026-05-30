#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_NAME="express-reliability-platform-v02"

REMOVE_VOLUMES=false
PRUNE_BUILD_CACHE=false

usage() {
  cat <<'EOF'
Usage: ./scripts/cleanup_v2.sh [options]

Stops and removes the V2 Docker Compose stack.

Options:
  --volumes       Also remove Compose-managed volumes.
  --prune-cache   Also prune unused Docker build cache.
  -h, --help      Show this help message.

Examples:
  ./scripts/cleanup_v2.sh
  ./scripts/cleanup_v2.sh --volumes
  ./scripts/cleanup_v2.sh --volumes --prune-cache
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --volumes)
      REMOVE_VOLUMES=true
      ;;
    --prune-cache)
      PRUNE_BUILD_CACHE=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

require_docker_compose() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker is not installed or not available in PATH."
    exit 1
  fi

  if ! docker compose version >/dev/null 2>&1; then
    echo "ERROR: Docker Compose plugin is not available. Install the docker compose plugin and retry."
    exit 1
  fi
}

print_header() {
  echo "================================================"
  echo "  Express Reliability Platform V2 Cleanup"
  echo "================================================"
}

compose_down() {
  local down_args=(down --remove-orphans --rmi local)

  if [[ "$REMOVE_VOLUMES" == true ]]; then
    down_args+=(--volumes)
  fi

  echo
  echo "Step 1: Stop containers and remove Compose resources..."
  docker compose "${down_args[@]}"
  echo "  Compose stack stopped and removed."
}

prune_build_cache() {
  if [[ "$PRUNE_BUILD_CACHE" == true ]]; then
    echo
    echo "Step 2: Prune unused Docker build cache..."
    docker builder prune -f
    echo "  Docker build cache pruned."
  else
    echo
    echo "Step 2: Skip Docker build cache prune."
    echo "  Use --prune-cache when you want to reclaim build-cache disk space."
  fi
}

verify_cleanup() {
  echo
  echo "Step 3: Verify V2 containers are not running..."

  local running
  running="$(docker ps \
    --filter "name=^/flask-api$" \
    --filter "name=^/node-api$" \
    --filter "name=^/web-ui$" \
    --format "{{.Names}}" || true)"

  if [[ -z "$running" ]]; then
    echo "  CONFIRMED: No V2 platform containers are running."
  else
    echo "  WARNING: These V2 containers are still running:"
    echo "$running" | sed 's/^/    - /'
    echo "  Run: docker compose down --remove-orphans"
  fi
}

main() {
  print_header
  require_docker_compose

  cd "$PROJECT_ROOT"
  echo "Project root: $PROJECT_ROOT"
  echo "Project name: $PROJECT_NAME"
  echo "Remove volumes: $REMOVE_VOLUMES"
  echo "Prune build cache: $PRUNE_BUILD_CACHE"

  compose_down
  prune_build_cache
  verify_cleanup

  echo
  echo "================================================"
  echo "  Cleanup complete"
  echo "  Next: move to V3 for cloud promotion practice."
  echo "================================================"
}

main "$@"
