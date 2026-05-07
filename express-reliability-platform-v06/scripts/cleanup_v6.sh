#!/bin/bash
# V6 teardown: uninstalls Helm releases, deletes the platform namespace,
# destroys the EKS cluster, drains and destroys V6's own bootstrap (S3 state
# bucket + DynamoDB lock table), and removes the EKS context from
# ~/.kube/config.
#
# Intentionally DOES NOT touch:
#   - V5's bootstrap S3 bucket or DynamoDB lock table.
#   - V5's ECR repositories or images (V7+ may still need them).
#
# Note: no `set -e` — we want each step to keep going even if a previous one
# partially failed, so a half-cleaned-up environment can be finished off.

ENV="${ENV:-dev}"
case "${ENV}" in
  dev|staging|prod) ;;
  *) echo "ERROR: ENV must be one of dev|staging|prod (got: ${ENV})" >&2; exit 1 ;;
esac

REGION="us-east-1"
NAMESPACE="platform"

echo "=== V6 Cleanup (env: ${ENV}) ==="
echo "This destroys the ${ENV} EKS cluster and (if no other env state remains)"
echo 'the V6 bootstrap state bucket, lock table, and ECR repos. Other envs in'
echo 'this same V6 stack are kept intact. V5 bootstrap is also kept intact.'
echo

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
STATE_BUCKET="reliability-platform-v06-tfstate-${ACCOUNT_ID}"
LOCK_TABLE="terraform-state-lock-v06"
CLUSTER_VPC_NAME="reliability-platform-v06-${ENV}-vpc"

echo '=== Step 1: Uninstall Helm releases ==='
helm uninstall web-ui node-api flask-api -n "${NAMESPACE}" 2>/dev/null \
  || echo '  (some releases were already absent)'

echo '=== Step 2: Delete platform namespace ==='
kubectl delete namespace "${NAMESPACE}" --ignore-not-found 2>/dev/null \
  || echo '  (namespace already absent)'

echo '=== Step 2b: Reap orphan AWS load balancers in the cluster VPC ==='
# `Service type=LoadBalancer` (web-ui) provisions an AWS LB outside Terraform's
# view. If the LB still exists when we hit `terraform destroy`, the LB's ENIs
# block subnet deletion and its EIPs block IGW detachment, with errors like:
#   - "DependencyViolation: subnet ... has dependencies and cannot be deleted"
#   - "DependencyViolation: Network ... has some mapped public address(es)"
# Helm uninstall + namespace delete *should* trigger LB cleanup, but Kubernetes
# returns success before AWS is done removing the LB. Poll until they're gone.
VPC_ID=$(aws ec2 describe-vpcs --region "${REGION}" \
  --filters "Name=tag:Name,Values=${CLUSTER_VPC_NAME}" \
  --query 'Vpcs[0].VpcId' --output text 2>/dev/null)

if [ -n "${VPC_ID}" ] && [ "${VPC_ID}" != "None" ]; then
  echo "  cluster VPC: ${VPC_ID}"

  # Defensively delete any Classic ELBs (k8s in-tree default) and v2 NLB/ALBs.
  for LB in $(aws elb describe-load-balancers --region "${REGION}" \
        --query "LoadBalancerDescriptions[?VPCId=='${VPC_ID}'].LoadBalancerName" \
        --output text 2>/dev/null); do
    echo "  deleting Classic ELB: ${LB}"
    aws elb delete-load-balancer --load-balancer-name "${LB}" --region "${REGION}" 2>/dev/null
  done
  for ARN in $(aws elbv2 describe-load-balancers --region "${REGION}" \
        --query "LoadBalancers[?VpcId=='${VPC_ID}'].LoadBalancerArn" \
        --output text 2>/dev/null); do
    echo "  deleting v2 LB: ${ARN}"
    aws elbv2 delete-load-balancer --load-balancer-arn "${ARN}" --region "${REGION}" 2>/dev/null
  done

  # Wait for AWS to release the ENIs the LBs were holding (up to ~3 minutes).
  echo '  waiting for LB ENIs to release...'
  for i in $(seq 1 18); do
    REMAINING=$(aws ec2 describe-network-interfaces --region "${REGION}" \
      --filters "Name=vpc-id,Values=${VPC_ID}" "Name=status,Values=in-use" \
      --query 'length(NetworkInterfaces)' --output text 2>/dev/null)
    [ "${REMAINING}" = "0" ] && break
    echo "    ${REMAINING} ENI(s) still in-use, retrying in 10s..."
    sleep 10
  done

  # Sweep any leftover available ENIs that AWS didn't auto-release.
  for ENI in $(aws ec2 describe-network-interfaces --region "${REGION}" \
        --filters "Name=vpc-id,Values=${VPC_ID}" "Name=status,Values=available" \
        --query 'NetworkInterfaces[].NetworkInterfaceId' --output text 2>/dev/null); do
    echo "  deleting orphan ENI: ${ENI}"
    aws ec2 delete-network-interface --network-interface-id "${ENI}" \
      --region "${REGION}" 2>/dev/null
  done
else
  echo '  no cluster VPC found — already destroyed or never deployed'
fi

echo "=== Step 3: Re-init EKS stack for ${ENV} against V6 bootstrap backend ==="
# Re-init in case .terraform/ was wiped by a prior partial cleanup. State key
# is per-env so this destroys only ${ENV}'s resources, leaving other envs
# (sharing the same bucket) untouched.
if [ -n "${ACCOUNT_ID}" ]; then
  terraform -chdir=platform/terraform/eks init \
    -reconfigure -input=false \
    -backend-config="bucket=${STATE_BUCKET}" \
    -backend-config="region=${REGION}" \
    -backend-config="dynamodb_table=${LOCK_TABLE}" \
    -backend-config="key=eks/v6/${ENV}/terraform.tfstate" >/dev/null 2>&1
fi

echo "=== Step 4: Destroy ${ENV} EKS Terraform (10-15 minutes) ==="
terraform -chdir=platform/terraform/eks destroy -auto-approve \
  -var-file="environments/${ENV}.tfvars"

echo "=== Step 4b: Detect other-env state in the bootstrap bucket ==="
# With per-env state keys (eks/v6/<env>/terraform.tfstate), the bootstrap
# bucket can hold state for multiple envs. Destroying the bucket would wipe
# any other env's state. Detect that case and skip steps 5/6 if found.
OTHER_ENV_STATE_FOUND=false
if [ -n "${ACCOUNT_ID}" ] && \
   aws s3api head-bucket --bucket "${STATE_BUCKET}" --region "${REGION}" 2>/dev/null; then
  for OTHER in dev staging prod; do
    [ "${OTHER}" = "${ENV}" ] && continue
    if aws s3api head-object --bucket "${STATE_BUCKET}" \
         --key "eks/v6/${OTHER}/terraform.tfstate" \
         --region "${REGION}" >/dev/null 2>&1; then
      echo "  found state for env=${OTHER} — preserving bootstrap (bucket + lock + ECR)."
      OTHER_ENV_STATE_FOUND=true
    fi
  done
  ${OTHER_ENV_STATE_FOUND} || echo "  no other-env state — safe to destroy bootstrap."
fi

if ${OTHER_ENV_STATE_FOUND}; then
  echo "=== Skipping steps 5-6 (bootstrap destroy) — other envs still exist ==="
  echo "    Re-run cleanup_v6.sh against the remaining envs first if you want"
  echo "    a full V6 teardown."
fi

echo '=== Step 5: Drain V6 state bucket (versions + delete markers) ==='
# Versioned bucket can't be terraform-destroyed while non-empty. Loop in
# batches of 1000 (the delete-objects per-call cap) until both Versions[]
# and DeleteMarkers[] are empty. force_destroy=true on the bucket gives
# a backup drain inside the AWS provider, but draining here first means
# the destroy output shows exactly how much state we removed.
if ! ${OTHER_ENV_STATE_FOUND} && \
   [ -n "${ACCOUNT_ID}" ] && \
   aws s3api head-bucket --bucket "${STATE_BUCKET}" --region "${REGION}" 2>/dev/null; then
  TOTAL=0
  while : ; do
    CHUNK=$(aws s3api list-object-versions --bucket "${STATE_BUCKET}" --region "${REGION}" \
      --no-paginate --max-keys 1000 \
      --query '{Objects: [Versions, DeleteMarkers][].{Key:Key,VersionId:VersionId}}' \
      --output json 2>/dev/null)
    echo "${CHUNK}" | grep -q '"Objects": null' && break
    COUNT=$(echo "${CHUNK}" | grep -c '"Key":' || true)
    [ "${COUNT}" -eq 0 ] && break
    if ! aws s3api delete-objects --bucket "${STATE_BUCKET}" --region "${REGION}" \
          --delete "${CHUNK}" >/dev/null 2>&1; then
      echo "  WARN: delete-objects failed on a batch of ${COUNT}; force_destroy will retry"
      break
    fi
    TOTAL=$((TOTAL + COUNT))
    echo "  drained ${COUNT} (running total: ${TOTAL})"
  done
  echo "  drained ${TOTAL} object(s) total"
else
  echo "  bucket s3://${STATE_BUCKET} not found — skipping drain"
fi

echo '=== Step 6: Destroy V6 bootstrap (S3 bucket + DynamoDB lock table) ==='
if ${OTHER_ENV_STATE_FOUND}; then
  echo '  skipped — bootstrap is still serving another env.'
else
  # Apply first so any local-only changes (force_destroy, etc.) are recorded
  # in state before destroy. Idempotent — no-op if state already matches.
  terraform -chdir=platform/terraform/bootstrap init -input=false >/dev/null 2>&1 || true
  terraform -chdir=platform/terraform/bootstrap apply -auto-approve >/dev/null 2>&1 || true
  terraform -chdir=platform/terraform/bootstrap destroy -auto-approve
fi

echo '=== Step 7: Remove kubectl context ==='
CTX=$(kubectl config current-context 2>/dev/null || true)
if [ -n "${CTX}" ]; then
  kubectl config delete-context "${CTX}" 2>/dev/null \
    && echo "  removed context: ${CTX}" \
    || echo "  context ${CTX} already absent"
fi

echo '=== Step 8: Verify cleanup ==='
echo "--- EKS clusters (should not include reliability-platform-${ENV}) ---"
aws eks list-clusters --region "${REGION}" --query 'clusters' --output text 2>/dev/null
if ${OTHER_ENV_STATE_FOUND}; then
  echo '--- V6 state bucket (kept — other envs still use it) ---'
  echo "  ${STATE_BUCKET}"
else
  echo '--- V6 state bucket (should not exist) ---'
  aws s3api head-bucket --bucket "${STATE_BUCKET}" --region "${REGION}" 2>&1 \
    | grep -q 'Not Found' && echo '  gone' || echo "  still present: ${STATE_BUCKET}"
  echo '--- V6 lock table (should not exist) ---'
  aws dynamodb describe-table --table-name "${LOCK_TABLE}" --region "${REGION}" \
    --query 'Table.TableStatus' --output text 2>/dev/null \
    || echo '  not found'
fi

echo '=== Step 9: Local Terraform artifacts cleanup ==='
for DIR in platform/terraform/bootstrap platform/terraform/eks; do
  rm -rf "${DIR}/.terraform" \
         "${DIR}/.terraform.lock.hcl" \
         "${DIR}/terraform.tfstate" \
         "${DIR}/terraform.tfstate.backup" \
         "${DIR}/tfplan" 2>/dev/null
  echo "  cleaned: ${DIR}"
done

echo
echo '=== Done! V6 teardown complete. ==='
echo 'V5 bootstrap and ECR repos are intact for V7-V10.'
echo 'To redeploy V6, run: ./scripts/tf_deploy_v6.sh'
