variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region the shared network lives in. Must match the bootstrap and live region."
}

variable "project_name" {
  type        = string
  default     = "reliability-platform-v07"
  description = "Used as a prefix for VPC, IGW, subnets, and route table tags. Cosmetic — used in resource Name tags only."
}

variable "version_suffix" {
  type        = string
  default     = "v07"
  description = "Cosmetic version tag carried on shared resources so audit tools can attribute them to V7."
}

variable "cluster_name" {
  type        = string
  default     = "reliability-platform-cluster"
  description = "EKS cluster name. Public subnets get the kubernetes.io/cluster/<this> tag so the LoadBalancer controller can find them. Must match the cluster_name passed to the live layer."
}

# 10.44.0.0/16 — deliberately distinct from V5's 10.42.0.0/16 and V6's
# 10.43.0.0/16 so all three VPCs could be peered later without overlapping.
variable "vpc_cidr" {
  type        = string
  default     = "10.44.0.0/16"
  description = "Primary IPv4 CIDR block for the shared VPC."
}
