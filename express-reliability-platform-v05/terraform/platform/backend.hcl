# Backend values that differ per AWS account.
# Terraform backend blocks cannot use variables.tf, so the account-specific state
# bucket name is set here and loaded at init time:
#
#   terraform -chdir=terraform/platform init -backend-config=backend.hcl
#
# Replace YOUR_ACCOUNT_ID below with your AWS account number, to match
# the bucket created by `terraform/bootstrap` (output: state_bucket).
bucket = "reliability-platform-tfstate-YOUR_ACCOUNT_ID"
