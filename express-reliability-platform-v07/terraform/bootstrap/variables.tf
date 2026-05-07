variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region the state bucket, lock table, and ECR repos live in."
}

variable "project_name" {
  type        = string
  default     = "reliability-platform"
  description = "Used as the prefix for the state bucket name and the ECR namespace."
}

# Lets V5 (no suffix), V6 (v06), V7 (v07), and future versions coexist on one
# AWS account without bucket / lock-table / ECR repo names colliding. The
# shared and live backends in main.tf must reference this same suffix —
# tf_deploy_v7.sh threads it through automatically.
variable "version_suffix" {
  type        = string
  default     = "v07"
  description = "Namespacing suffix for resource names. Keep it short — bucket names cap at 63 chars."
}

variable "services" {
  type        = list(string)
  default     = ["flask-api", "node-api", "web-ui"]
  description = "Service names — one ECR repo is created per entry, named <project_name>/<service>."
}
