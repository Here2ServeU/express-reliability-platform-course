#!/bin/bash
NAMESPACE=${NAMESPACE:-'platform'}
SERVICE=${1:-'flask-api-flask-api'}
DURATION=${DURATION:-60}   # seconds of load

echo "=== Chaos Drill 3: CPU Pressure ==="
echo "Generating ${DURATION}s of CPU load on ${SERVICE}..."

# Get a running pod
POD=$(kubectl get pods -n "$NAMESPACE" -l app="$SERVICE" \
  -o jsonpath='{.items[0].metadata.name}')

# Run a CPU-burning command inside the pod for DURATION seconds
# 'yes > /dev/null' generates infinite CPU load, killed after DURATION seconds
kubectl exec "$POD" -n "$NAMESPACE" -- \
  timeout "$DURATION" sh -c 'yes > /dev/null &' 2>/dev/null || true

echo "CPU load running. Watching HPA for ${DURATION} seconds..."
echo "(HPA reacts within 30-60 seconds after Metrics Server updates)"

# Watch HPA in the background
timeout "$DURATION" kubectl get hpa -n "$NAMESPACE" -w || true

echo ""
echo "Final HPA state:"
kubectl get hpa -n "$NAMESPACE"

echo "=== Drill 3 complete. CPU load ended. ==="
