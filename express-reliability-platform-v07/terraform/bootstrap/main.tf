terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" { region = "us-east-1" }

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "tfstate" {
  bucket        = "reliability-platform-v07-tfstate-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_dynamodb_table" "tflock" {
  name         = "terraform-state-lock-v07"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}

resource "aws_ecr_repository" "services" {
  for_each     = toset(["flask-api", "node-api", "web-ui"])
  name         = "reliability-platform/${each.key}"
  force_delete = true
}

output "account_id"   { value = data.aws_caller_identity.current.account_id }
output "state_bucket" { value = aws_s3_bucket.tfstate.bucket }
output "ecr_base" {
  value = "${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-1.amazonaws.com/reliability-platform"
}
