#!/bin/bash
# Chaos Drill 4: Crash Loop Simulation
# Deploy a pod that crashes on startup, confirm CrashLoopBackOff, then clean up.
set -e
NAMESPACE=${NAMESPACE:-"platform"}

echo "=== Chaos Drill 4: Crash Loop ==="

kubectl apply -n "$NAMESPACE" -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: chaos-crashloop-test
  labels:
    app: chaos-test
spec:
  containers:
    - name: crasher
      image: busybox:1.36
      command: ["sh", "-c", "echo Starting; sleep 2; echo Crashing; exit 1"]
      resources:
        limits:
          cpu: 50m
          memory: 32Mi
        requests:
          cpu: 10m
          memory: 16Mi
YAML

echo "Waiting for the pod to enter CrashLoopBackOff..."
sleep 30
kubectl get pods -n "$NAMESPACE" -l app=chaos-test
kubectl logs chaos-crashloop-test -n "$NAMESPACE" --previous 2>/dev/null || true

echo "Cleaning up the crash-loop test pod..."
kubectl delete pod chaos-crashloop-test -n "$NAMESPACE" --grace-period=0 2>/dev/null || true

echo "=== Drill 4 complete. ==="
