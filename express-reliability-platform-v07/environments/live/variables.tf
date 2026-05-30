variable "environment_name" {
  description = "Name of the environment (e.g., live)"
  type        = string
  default     = "live"
}

variable "region" {
  description = "AWS region for live environment"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC ID for EKS and ALB"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for EKS and ALB"
  type        = list(string)
}

# Add more variables as needed for Helm chart values, node group configuration, etc.
