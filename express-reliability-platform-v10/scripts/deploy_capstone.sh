#!/bin/bash
# deploy_capstone.sh: one command brings up the complete platform on GKE.
#
#   export PROJECT_ID=my-gcp-project
#   export ALERT_EMAIL=you@example.com     # optional: SLO burn-rate alerts
#   export AUTOPILOT=false                 # true = GKE Autopilot
#   ./scripts/deploy_capstone.sh
set -euo pipefail

: "${PROJECT_ID:?Set PROJECT_ID to your Google Cloud project ID}"
REGION="${REGION:-us-central1}"
ZONE="${ZONE:-us-central1-a}"
AUTOPILOT="${AUTOPILOT:-false}"
ALERT_EMAIL="${ALERT_EMAIL:-}"
NAMESPACE="platform"
KSA="platform-workload"
TF_VARS=(-var "project_id=${PROJECT_ID}" -var "region=${REGION}")

gcloud config set project "$PROJECT_ID" >/dev/null

echo '=== Step 1: Bootstrap (APIs, GCS state bucket, Artifact Registry) ==='
terraform -chdir=platform/terraform/bootstrap init -input=false
terraform -chdir=platform/terraform/bootstrap apply -auto-approve "${TF_VARS[@]}"
BUCKET=$(terraform -chdir=platform/terraform/bootstrap output -raw state_bucket)

echo '=== Step 2: Build and push images to Artifact Registry ==='
TAG=$(./scripts/build_push_images.sh | tail -1)
REGISTRY=$(terraform -chdir=platform/terraform/bootstrap output -raw registry)

echo '=== Step 3: Shared layer (VPC, subnet, Cloud NAT) ==='
terraform -chdir=platform/terraform/shared init -reconfigure -input=false -backend-config="bucket=${BUCKET}"
terraform -chdir=platform/terraform/shared apply -auto-approve "${TF_VARS[@]}"

echo '=== Step 4: Live layer (GKE cluster, Workload Identity, SLOs) ==='
terraform -chdir=platform/terraform/live init -reconfigure -input=false -backend-config="bucket=${BUCKET}"
terraform -chdir=platform/terraform/live apply -auto-approve "${TF_VARS[@]}" \
  -var "zone=${ZONE}" -var "state_bucket=${BUCKET}" \
  -var "autopilot=${AUTOPILOT}" -var "alert_email=${ALERT_EMAIL}"
CLUSTER=$(terraform -chdir=platform/terraform/live output -raw cluster_name)
LOCATION=$(terraform -chdir=platform/terraform/live output -raw cluster_location)
WORKLOAD_SA=$(terraform -chdir=platform/terraform/live output -raw workload_service_account)
gcloud container clusters get-credentials "$CLUSTER" --location "$LOCATION" --project "$PROJECT_ID"

echo '=== Step 5: Namespace + Workload Identity service account ==='
kubectl apply -f governance/namespaces/platform-ns.yaml
kubectl create serviceaccount "$KSA" -n "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl annotate serviceaccount "$KSA" -n "$NAMESPACE" --overwrite \
  iam.gke.io/gcp-service-account="$WORKLOAD_SA"

echo "=== Step 6: Install Helm charts (image tag: ${TAG}) ==="
for SVC in flask-api node-api web-ui; do
  helm upgrade --install "$SVC" "platform/helm/${SVC}" \
    --namespace "$NAMESPACE" \
    --set image.repository="${REGISTRY}/${SVC}" \
    --set image.tag="${TAG}" \
    --wait --timeout 10m
done

echo '=== Step 7: Governance (OPA Gatekeeper) ==='
if [ "$AUTOPILOT" = "true" ]; then
  echo '  Autopilot: skipping open-source Gatekeeper (use GKE Policy Controller instead).'
else
  kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/v3.14.0/deploy/gatekeeper.yaml
  kubectl -n gatekeeper-system rollout status deployment/gatekeeper-controller-manager --timeout=180s
  kubectl apply -f governance/gatekeeper/templates/
  sleep 10
  kubectl apply -f governance/gatekeeper/constraints/
fi

echo '=== Step 8: Monitoring (Managed Prometheus scraping + alert rules) ==='
kubectl apply -f monitoring/gmp/

echo '================================================='
echo 'Capstone deployment complete on GKE.'
echo "  Cluster:  ${CLUSTER} (${LOCATION})"
echo "  Web UI:   kubectl get svc web-ui-web-ui -n ${NAMESPACE}"
echo "  SLOs:     https://console.cloud.google.com/monitoring/services?project=${PROJECT_ID}"
echo '================================================='
