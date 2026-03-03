provider "aws" {
  region = var.region
}

resource "aws_s3_bucket" "shared_bucket" {
  bucket = "shared-platform-bucket-${var.environment_name}"
  acl    = "private"
  tags = {
    Name        = "SharedBucket"
    Environment = var.environment_name
  }
}
