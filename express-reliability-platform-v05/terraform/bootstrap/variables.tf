variable "region" {
  description = "AWS region for the Terraform state backend resources."
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_prefix" {
  description = "Prefix for the S3 state bucket. The AWS account ID is appended to keep the bucket name globally unique."
  type        = string
  default     = "reliability-platform-tfstate"
}

variable "lock_table_name" {
  description = "Name of the DynamoDB table used for Terraform state locking."
  type        = string
  default     = "reliability-platform-tfstate-lock"
}
