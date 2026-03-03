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
