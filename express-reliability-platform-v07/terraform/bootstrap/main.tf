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

# S3 bucket for storing V7 Terraform state files.
#
# Naming: ${project_name}-${version_suffix}-tfstate-${account_id}. The
# version-suffix lets V5/V6/V7 coexist on a single AWS account without bucket
# name collisions. V7's separation of `shared` and `live` layers lives inside
# this single bucket at different keys (shared/v7/terraform.tfstate vs
# live/v7/terraform.tfstate) so deleting one layer's state cannot affect the
# other's.
resource "aws_s3_bucket" "tf_state" {
  bucket = "${var.project_name}-${var.version_suffix}-tfstate-${data.aws_caller_identity.current.account_id}"

  # Versioning is on (next resource), so a plain `terraform destroy` would
  # 409 with BucketNotEmpty — versions and delete-markers survive `aws s3 rm`.
  # force_destroy = true tells the AWS provider to drain every version and
  # delete-marker before calling DeleteBucket. The cleanup script also drains
  # the bucket before destroy so the destroy plan shows exactly what's removed.
  force_destroy = true

  tags = {
    Name      = "TerraformState-${var.version_suffix}"
    ManagedBy = "terraform"
    Purpose   = "state-storage"
    Version   = var.version_suffix
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "block" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for state locking. The shared and live layers BOTH lock
# against this single table — DynamoDB locks are scoped by the LockID hash
# key (which Terraform sets to the state file path), so two layers writing
# different state files never block each other.
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
