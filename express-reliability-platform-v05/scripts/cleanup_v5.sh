#!/bin/bash
set -e

REGION=us-east-1

echo "Step 1: Removing Kubernetes resources (releases ALB)..."
kubectl delete namespace reliability --ignore-not-found

echo "Step 2: Waiting 60 seconds for ALB to be fully released..."
echo "(terraform destroy fails if the ALB still exists)"
sleep 60

echo "Step 3: Destroying all Terraform-managed platform resources (EKS, VPC, etc.)..."
echo "This takes 10-15 minutes. Do not close the terminal."
terraform -chdir=terraform/platform destroy -auto-approve

echo "Step 4: Emptying the Terraform state bucket so it can be deleted..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="reliability-platform-tfstate-${ACCOUNT_ID}"

# Versioning is enabled, so a plain 'aws s3 rm' leaves old versions behind and the
# bucket cannot be deleted. Delete every object version AND delete marker, looping
# until none remain (list-object-versions returns at most 1000 per page).
empty_versioned_bucket() {
  local bucket="$1"
  if ! aws s3api head-bucket --bucket "$bucket" --region "$REGION" 2>/dev/null; then
    echo "Bucket $bucket not found, skipping empty step."
    return 0
  fi
  while true; do
    local payload
    payload=$(aws s3api list-object-versions --bucket "$bucket" --region "$REGION" \
      --max-items 1000 \
      --query '{Objects: [Versions, DeleteMarkers][][].{Key:Key,VersionId:VersionId}}' \
      --output json)
    # No Objects array (or empty) means the bucket is clean.
    if [ -z "$payload" ] || echo "$payload" | grep -q '"Objects": null' || echo "$payload" | grep -q '"Objects": \[\]'; then
      break
    fi
    aws s3api delete-objects --bucket "$bucket" --region "$REGION" --delete "$payload" \
      --query 'Deleted | length(@)' --output text
  done
  echo "Bucket $bucket is empty."
}
empty_versioned_bucket "$BUCKET"

echo "Step 5: Destroying the bootstrap backend (S3 state bucket + DynamoDB lock table)..."
terraform -chdir=terraform/bootstrap destroy -auto-approve

echo "=== Done. Platform AND bootstrap backend destroyed. ==="
echo "Verify nothing remains:"
echo "  aws eks list-clusters --region ${REGION}"
echo "  aws s3 ls | grep reliability-platform-tfstate || echo 'no state bucket'"
echo "  aws dynamodb list-tables --region ${REGION} | grep reliability-platform-tfstate-lock || echo 'no lock table'"
