#!/bin/bash
# V7 teardown — MANDATORY reverse order: Helm → live → shared → bootstrap.
#
# Why the order matters: live's terraform_remote_state data source READS
# shared's state during its own destroy. Destroying shared first orphans
# live's IAM roles and node group with VPC IDs that no longer resolve, and
# `terraform destroy` in live then fails with confusing "vpc_id is null"
# errors. Always destroy top-down.
#
# Note: no `set -e` — we want each step to keep going even if a previous one
# partially failed, so a half-cleaned-up environment can be finished off.

REGION="us-east-1"
NAMESPACE="platform"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
V7_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo '=== V7 Cleanup ==='
echo 'Order: Helm → live → shared → bootstrap. Destroys EKS, the V7 VPC,'
echo 'and the V7 bootstrap (state bucket + lock table + ECR repos with'
echo 'all pushed images). V5 and V6 bootstraps (if present) are kept intact.'
echo

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
STATE_BUCKET="reliability-platform-v07-tfstate-${ACCOUNT_ID}"
LOCK_TABLE="terraform-state-lock-v07"

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
  --filters "Name=tag:Name,Values=reliability-platform-v07-vpc" \
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

echo '=== Step 3: Re-init LIVE layer against V7 bootstrap backend ==='
# Re-init in case .terraform/ was wiped by a prior partial cleanup. Pass the
# backend via flags so this works even if main.tf still has the
# YOUR_ACCOUNT_ID placeholder.
if [ -n "${ACCOUNT_ID}" ]; then
  terraform -chdir="${V7_ROOT}/terraform/live" init \
    -reconfigure -input=false \
    -backend-config="bucket=${STATE_BUCKET}" \
    -backend-config="region=${REGION}" \
    -backend-config="dynamodb_table=${LOCK_TABLE}" \
    -backend-config="key=live/v7/terraform.tfstate" >/dev/null 2>&1
fi

echo '=== Step 4: Destroy LIVE Terraform (EKS — 10-15 minutes) ==='
terraform -chdir="${V7_ROOT}/terraform/live" destroy -auto-approve \
  -var "state_bucket=${STATE_BUCKET}"

echo '=== Step 5: Re-init SHARED layer against V7 bootstrap backend ==='
if [ -n "${ACCOUNT_ID}" ]; then
  terraform -chdir="${V7_ROOT}/terraform/shared" init \
    -reconfigure -input=false \
    -backend-config="bucket=${STATE_BUCKET}" \
    -backend-config="region=${REGION}" \
    -backend-config="dynamodb_table=${LOCK_TABLE}" \
    -backend-config="key=shared/v7/terraform.tfstate" >/dev/null 2>&1
fi

echo '=== Step 6: Destroy SHARED Terraform (VPC + subnets + IGW) ==='
terraform -chdir="${V7_ROOT}/terraform/shared" destroy -auto-approve

echo '=== Step 7: Drain V7 state bucket (versions + delete markers) ==='
# Versioned bucket can't be terraform-destroyed while non-empty. Loop in
# batches of 1000 until both Versions[] and DeleteMarkers[] are empty.
# force_destroy=true gives a backup drain inside the AWS provider, but
# draining here first means the destroy output shows exactly how much
# state we removed.
if [ -n "${ACCOUNT_ID}" ] && \
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

echo '=== Step 8: Destroy V7 bootstrap (state bucket + lock table + ECR repos) ==='
# Apply first so any local-only changes (force_destroy, etc.) are recorded
# in state before destroy. Idempotent — no-op if state already matches.
terraform -chdir="${V7_ROOT}/terraform/bootstrap" init -input=false >/dev/null 2>&1 || true
terraform -chdir="${V7_ROOT}/terraform/bootstrap" apply -auto-approve >/dev/null 2>&1 || true
terraform -chdir="${V7_ROOT}/terraform/bootstrap" destroy -auto-approve

echo '=== Step 9: Remove kubectl context ==='
CTX=$(kubectl config current-context 2>/dev/null || true)
if [ -n "${CTX}" ]; then
  kubectl config delete-context "${CTX}" 2>/dev/null \
    && echo "  removed context: ${CTX}" \
    || echo "  context ${CTX} already absent"
fi

echo '=== Step 10: Verify cleanup ==='
echo '--- EKS clusters (should not include reliability-platform-cluster) ---'
aws eks list-clusters --region "${REGION}" --query 'clusters' --output text 2>/dev/null
echo '--- V7 state bucket (should not exist) ---'
aws s3api head-bucket --bucket "${STATE_BUCKET}" --region "${REGION}" 2>&1 \
  | grep -q 'Not Found' && echo '  gone' || echo "  still present: ${STATE_BUCKET}"
echo '--- V7 lock table (should not exist) ---'
aws dynamodb describe-table --table-name "${LOCK_TABLE}" --region "${REGION}" \
  --query 'Table.TableStatus' --output text 2>/dev/null \
  || echo '  not found'

echo '=== Step 11: Local Terraform artifacts cleanup ==='
for DIR in terraform/bootstrap terraform/shared terraform/live; do
  rm -rf "${V7_ROOT}/${DIR}/.terraform" \
         "${V7_ROOT}/${DIR}/.terraform.lock.hcl" \
         "${V7_ROOT}/${DIR}/terraform.tfstate" \
         "${V7_ROOT}/${DIR}/terraform.tfstate.backup" \
         "${V7_ROOT}/${DIR}/tfplan" 2>/dev/null
  echo "  cleaned: ${DIR}"
done

echo
echo '=== Done! V7 teardown complete. ==='
echo 'V5 and V6 bootstraps (if present) are intact.'
echo 'To redeploy V7, run: ./scripts/tf_deploy_v7.sh'
