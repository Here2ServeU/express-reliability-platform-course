variable "environment_name" {
  description = "Name of the environment (e.g., shared)"
  type        = string
  default     = "shared"
}

variable "region" {
  description = "AWS region for shared environment"
  type        = string
  default     = "us-east-1"
}
