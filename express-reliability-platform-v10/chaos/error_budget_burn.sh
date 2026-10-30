#!/bin/bash
# Chaos Drill 5 (V10): burn the error budget on purpose and watch the
# SLO burn-rate alert fire in Cloud Monitoring.
#
# 1. Make flask-api fail ERROR_RATE of /score requests (default 20%)
# 2. Send traffic for DURATION seconds
# 3. Roll back and measure time to recovery
set -e
NAMESPACE=${NAMESPACE:-platform}
DEPLOY=flask-api-flask-api
ERROR_RATE=${ERROR_RATE:-0.2}
DURATION=${DURATION:-300}
RECOVERY_SLO=${RECOVERY_SLO:-90}

echo "=== Chaos Drill 5: Error-Budget Burn (${ERROR_RATE} failure rate for ${DURATION}s) ==="
kubectl set env deployment/"$DEPLOY" -n "$NAMESPACE" ERROR_RATE="$ERROR_RATE"
kubectl rollout status deployment/"$DEPLOY" -n "$NAMESPACE" --timeout=120s

echo "Generating traffic from inside the cluster..."
kubectl run load-gen -n "$NAMESPACE" --rm -i --restart=Never \
  --image=curlimages/curl:8.10.1 \
  --overrides='{"spec":{"containers":[{"name":"load-gen","image":"curlimages/curl:8.10.1","resources":{"requests":{"cpu":"50m","memory":"32Mi"},"limits":{"cpu":"100m","memory":"64Mi"}},"command":["sh","-c","end=$(( $(date +%s) + '"$DURATION"' )); ok=0; bad=0; while [ $(date +%s) -lt $end ]; do code=$(curl -s -o /dev/null -w %{http_code} http://flask-api-flask-api:5000/score?input=chaos+drill); [ \"$code\" = 200 ] && ok=$((ok+1)) || bad=$((bad+1)); sleep 0.2; done; echo ok=$ok bad=$bad"]}]}}' \
  || true

echo "Check Cloud Monitoring > Services > erp-flask-api for the burn-rate alert."
echo "Rolling back the fault..."
START=$(date +%s)
kubectl set env deployment/"$DEPLOY" -n "$NAMESPACE" ERROR_RATE-
kubectl rollout status deployment/"$DEPLOY" -n "$NAMESPACE" --timeout=120s
RECOVERY_TIME=$(( $(date +%s) - START ))

if [ "$RECOVERY_TIME" -le "$RECOVERY_SLO" ]; then RESULT=PASSED; else RESULT=FAILED; fi
echo "DRILL ${RESULT}: recovered in ${RECOVERY_TIME}s (SLO: ${RECOVERY_SLO}s)"

SLACK_WEBHOOK_URL=${SLACK_WEBHOOK_URL:-''} \
  ./incident/slack_alert.sh INFO \
  "Chaos Drill 5: Error-Budget Burn - ${RESULT}" \
  "Failure rate: ${ERROR_RATE} | Recovery: ${RECOVERY_TIME}s | SLO: ${RECOVERY_SLO}s" \
  "chaos-drill" || true
