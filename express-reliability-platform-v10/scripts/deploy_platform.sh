#!/bin/bash
# deploy_platform.sh: one command brings up the complete platform on the cloud you choose.
#
#   CLOUD=aws ./scripts/deploy_platform.sh   # the V9 platform on EKS, with V10's fixes
#   CLOUD=gcp ./scripts/deploy_platform.sh   # the same platform on GKE, plus Cloud Monitoring SLOs
set -euo pipefail

case "${CLOUD:-}" in
  aws|gcp) exec "$(dirname "$0")/deploy_${CLOUD}.sh" ;;
  *) echo 'Set CLOUD=aws or CLOUD=gcp' >&2; exit 1 ;;
esac
