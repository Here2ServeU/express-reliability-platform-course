# Backend values that differ per AWS account.
# Terraform backend blocks cannot use variables.tf, so the account-specific state
# bucket name is set here and loaded at init time:
#
#   terraform -chdir=terraform/platform init -backend-config=backend.hcl
#
# To use a different account, change only the account-number suffix below to match
# the bucket created by `terraform/bootstrap` (output: state_bucket).
bucket = "reliability-platform-tfstate-730335276920"
