provider "aws" {
  region = var.region
}

resource "aws_s3_bucket" "shared_bucket" {
  bucket = "shared-platform-bucket-${var.environment_name}"
  tags = {
    Name        = "SharedBucket"
    Environment = var.environment_name
  }
}

resource "aws_s3_bucket_public_access_block" "shared_bucket_access" {
  bucket = aws_s3_bucket.shared_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
