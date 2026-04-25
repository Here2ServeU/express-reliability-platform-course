terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Read our own account ID without hardcoding it
data "aws_caller_identity" "current" {}

# S3 bucket for storing all Terraform state files
resource "aws_s3_bucket" "tf_state" {
  bucket = "reliability-platform-tfstate-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name      = "TerraformState"
    ManagedBy = "terraform"
    Purpose   = "state-storage"
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

# DynamoDB table for state locking
resource "aws_dynamodb_table" "tf_lock" {
  name         = "terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name      = "TerraformLock"
    ManagedBy = "terraform"
  }
}

output "state_bucket" {
  value = aws_s3_bucket.tf_state.id
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}
