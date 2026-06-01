variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region the state bucket and lock table live in."
}

variable "project_name" {
  type        = string
  default     = "reliability-platform"
  description = "Used as the prefix for the state bucket name."
}

# Lets V5 (no suffix), V6 (v06), V7+ versions coexist on one AWS account
# without the bucket / lock table names colliding. If you change this, the
# EKS stack's backend.tf bucket name must change to match: keep the two
# stacks' version_suffix in lockstep.
variable "version_suffix" {
  type        = string
  default     = "v06"
  description = "Namespacing suffix for resource names. Keep it short: bucket names cap at 63 chars."
}

variable "services" {
  type        = list(string)
  default     = ["flask-api", "node-api", "web-ui"]
  description = "Service names: one ECR repo is created per entry, named <project_name>/<service>."
}
