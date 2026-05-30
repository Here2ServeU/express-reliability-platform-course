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

resource "aws_s3_bucket_acl" "shared_bucket_acl" {
  bucket = aws_s3_bucket.shared_bucket.id
  acl    = "private"
}
