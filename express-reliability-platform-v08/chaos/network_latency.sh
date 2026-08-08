#!/bin/bash
# Chaos drill: inject network latency into a service pod and watch the HPA /
# error rate respond. Requires the tc/netem tools (NET_ADMIN) inside the pod.
NAMESPACE=${NAMESPACE:-'platform'}
SERVICE=${1:-'flask-api-flask-api'}
DELAY_MS=${DELAY_MS:-300}
DURATION=${DURATION:-60}

echo "=== Chaos Drill: Network Latency (${DELAY_MS}ms for ${DURATION}s) ==="

POD=$(kubectl get pods -n "$NAMESPACE" -l app="$SERVICE" \
  -o jsonpath='{.items[0].metadata.name}')
echo "Target pod: $POD"

# Add latency to the pod's primary interface, then remove it after DURATION.
kubectl exec "$POD" -n "$NAMESPACE" -- \
  sh -c "tc qdisc add dev eth0 root netem delay ${DELAY_MS}ms" 2>/dev/null \
  || echo "  (tc unavailable in image — simulate latency at the app layer instead)"

echo "Latency injected. Watching HPA for ${DURATION}s..."
timeout "$DURATION" kubectl get hpa -n "$NAMESPACE" -w || true

# Remove the latency rule
kubectl exec "$POD" -n "$NAMESPACE" -- \
  sh -c "tc qdisc del dev eth0 root netem" 2>/dev/null || true

echo "=== Network latency drill complete. ==="
