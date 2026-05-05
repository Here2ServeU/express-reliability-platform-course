terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Read our own account ID without hardcoding it
data "aws_caller_identity" "current" {}

# S3 bucket for storing V6 Terraform state files.
#
# Naming: ${project_name}-${version_suffix}-tfstate-${account_id} — deliberately
# version-suffixed so V5 (`reliability-platform-tfstate-...`), V6
# (`reliability-platform-v06-tfstate-...`), and any future versions can coexist
# on one AWS account. Different version, different bucket — no conflicts, no
# shared blast radius.
resource "aws_s3_bucket" "tf_state" {
  bucket = "${var.project_name}-${var.version_suffix}-tfstate-${data.aws_caller_identity.current.account_id}"

  # Versioning is enabled on this bucket (next resource), so a plain
  # `terraform destroy` would 409 with BucketNotEmpty — versions and delete
  # markers survive `aws s3 rm`. force_destroy = true tells the AWS provider
  # to drain every version and delete-marker before calling DeleteBucket,
  # which is what we want for a course-managed state backend.
  #
  # Trade-off: anyone running `terraform destroy` on this stack wipes every
  # version of every state file the bucket holds. That's fine here because
  # this bucket only ever stores ${project_name}-${version_suffix} state for
  # the same account, but don't copy this pattern to a shared/prod state bucket.
  force_destroy = true

  tags = {
    Name      = "TerraformState-${var.version_suffix}"
    ManagedBy = "terraform"
    Purpose   = "state-storage"
    Version   = var.version_suffix
  }
}

# Enable versioning — keeps every version of every state file
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Block all public access — state files may contain sensitive data
resource "aws_s3_bucket_public_access_block" "block" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for state locking — version-suffixed so it doesn't collide
# with V5's `terraform-state-lock` table or any other version's table.
resource "aws_dynamodb_table" "tf_lock" {
  name         = "terraform-state-lock-${var.version_suffix}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name      = "TerraformLock-${var.version_suffix}"
    ManagedBy = "terraform"
    Version   = var.version_suffix
  }
}

output "state_bucket" {
  value = aws_s3_bucket.tf_state.id
}

output "lock_table" {
  value = aws_dynamodb_table.tf_lock.name
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}
