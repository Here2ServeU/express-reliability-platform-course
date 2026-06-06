#!/usr/bin/env bash
set -euo pipefail

INTERVAL_SECONDS="${INTERVAL_SECONDS:-30}"

while true; do
  ./automation/fix_crashloop.sh || true
  ./automation/fix_memory_pressure.sh || true
  ./automation/fix_unreachable.sh || true
  sleep "$INTERVAL_SECONDS"
done
