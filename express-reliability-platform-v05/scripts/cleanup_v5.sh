#!/bin/bash
set -e

echo "Step 1: Removing Kubernetes resources (releases ALB)..."
kubectl delete namespace reliability --ignore-not-found

echo "Step 2: Waiting 60 seconds for ALB to be fully released..."
echo "(terraform destroy fails if the ALB still exists)"
sleep 60

echo "Step 3: Destroying all Terraform-managed AWS resources..."
echo "This takes 10-15 minutes. Do not close the terminal."
terraform -chdir=terraform/platform destroy -auto-approve

echo "=== Done. Bootstrap S3 + DynamoDB kept for Version 6. ==="
echo "Verify: aws eks list-clusters --region us-east-1"
