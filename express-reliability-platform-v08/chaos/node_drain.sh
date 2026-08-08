#!/bin/bash
set -e
NAMESPACE=${NAMESPACE:-'platform'}

echo "=== Chaos Drill 2: Node Drain ==="

# Get a worker node name (not the one with the most pods if possible)
NODE=$(kubectl get nodes -o name | head -1 | cut -d/ -f2)
echo "Draining node: $NODE"

# Cordon the node: stop new pods from being scheduled here
kubectl cordon "$NODE"
echo "Node cordoned: no new pods will be scheduled here"

# Drain: evict all pods off this node
# --ignore-daemonsets: DaemonSet pods are managed differently and stay
# --delete-emptydir-data: allow pods with ephemeral storage to be evicted
kubectl drain "$NODE" \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --grace-period=30

echo "Node drained. Watching pod rescheduling..."

# Watch pods reschedule on other nodes (30 second window)
timeout 60 kubectl get pods -n "$NAMESPACE" -w || true

# Verify all platform pods are still running on remaining nodes
RUNNING=$(kubectl get pods -n "$NAMESPACE" \
  --field-selector status.phase=Running --no-headers | wc -l | tr -d ' ')
echo "Running pods after drain: $RUNNING"

# Uncordon: allow the node to accept pods again
kubectl uncordon "$NODE"
echo "Node uncordoned: $NODE is accepting pods again"

echo "=== Drill 2 complete ==="
