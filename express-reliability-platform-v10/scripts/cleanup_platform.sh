#!/bin/bash
# cleanup_platform.sh: remove every resource on the cloud you choose.
# Run this at the end of each lab session to keep cost near zero.
#
#   CLOUD=aws ./scripts/cleanup_platform.sh
#   CLOUD=gcp ./scripts/cleanup_platform.sh
set -euo pipefail

case "${CLOUD:-}" in
  aws|gcp) exec "$(dirname "$0")/cleanup_${CLOUD}.sh" ;;
  *) echo 'Set CLOUD=aws or CLOUD=gcp' >&2; exit 1 ;;
esac
