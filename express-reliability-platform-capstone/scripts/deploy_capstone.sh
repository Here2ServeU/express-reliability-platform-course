#!/usr/bin/env bash
set -euo pipefail

echo "Deploying capstone platform..."

if [ -x "./scripts/deploy_all.sh" ]; then
  ./scripts/deploy_all.sh
else
  echo "No deploy_all.sh found. Run bootstrap, image push, shared, live, Helm, governance, and monitoring steps manually."
fi

echo "Capstone deployment complete."
