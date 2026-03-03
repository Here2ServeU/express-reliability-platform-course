terraform {
  required_version = ">= 1.5.0"
  backend "local" {}
}

provider "aws" {
  region = var.region
}

resource "aws_s3_bucket" "bootstrap" {
  bucket = "express-reliability-platform-bootstrap-${var.environment_name}"
  acl    = "private"
  tags = {
    Name        = "ExpressReliabilityPlatformBootstrap"
    Environment = var.environment_name
  }
}

resource "aws_iam_role" "bootstrap_role" {
  name = "express-reliability-platform-bootstrap-role-${var.environment_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "ExpressReliabilityPlatformBootstrapRole"
    Environment = var.environment_name
  }
}

resource "aws_s3_bucket" "tf_state" {
  bucket = var.state_bucket_name
  versioning {
    enabled = true
  }
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_dynamodb_table" "tf_lock" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
  point_in_time_recovery_enabled = true
}
