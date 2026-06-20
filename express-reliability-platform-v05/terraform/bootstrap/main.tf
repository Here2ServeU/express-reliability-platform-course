terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

# The S3 bucket that stores Terraform's memory file.
# force_destroy = true lets `terraform destroy` delete the bucket even though
# versioning keeps old state versions — otherwise teardown fails with BucketNotEmpty.
resource "aws_s3_bucket" "tfstate" {
  bucket        = "reliability-platform-tfstate-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

# Enable versioning so you can recover old memory files if needed
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration { status = "Enabled" }
}

# The lock table — prevents two terraform apply commands at the same time
resource "aws_dynamodb_table" "tflock" {
  name         = "reliability-platform-tfstate-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}

output "state_bucket" { value = aws_s3_bucket.tfstate.bucket }
output "account_id" { value = data.aws_caller_identity.current.account_id }
