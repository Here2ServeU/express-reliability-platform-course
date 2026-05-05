variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region the EKS cluster lives in. Must match the bootstrap region."
}

variable "project_name" {
  type        = string
  default     = "reliability-platform-v06"
  description = "Used as a prefix for VPC, IGW, subnets, route table, etc. tags."
}

variable "cluster_name" {
  type        = string
  default     = "reliability-platform-cluster"
  description = "EKS cluster name. Worker subnets get the kubernetes.io/cluster/<this> tag."
}

variable "kubernetes_version" {
  type        = string
  default     = "1.33"
  description = "EKS control-plane Kubernetes version. AWS retires versions ~14 months after K8s release — check `aws eks describe-cluster-versions` for the currently supported list and bump this when the AMI for the current default is retired."
}

# 10.43.0.0/16 — deliberately distinct from V5's 10.42.0.0/16 so the two VPCs
# could be peered later without overlapping CIDRs.
variable "vpc_cidr" {
  type        = string
  default     = "10.43.0.0/16"
  description = "Primary IPv4 CIDR block for the EKS VPC."
}

variable "node_instance_types" {
  type        = list(string)
  default     = ["t3.medium"]
  description = "EC2 instance types for the EKS managed node group."
}

variable "node_desired_size" {
  type        = number
  default     = 2
  description = "Desired worker node count. Two nodes are enough for the V6 self-healing demo."
}

variable "node_min_size" {
  type        = number
  default     = 1
  description = "Minimum worker node count for the managed node group."
}

variable "node_max_size" {
  type        = number
  default     = 4
  description = "Maximum worker node count. Bump this if you scale a Deployment past 4 replicas."
}
