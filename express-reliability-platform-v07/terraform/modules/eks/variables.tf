variable "cluster_name" {
  type        = string
  description = "Name for the EKS cluster. Becomes the EKS resource's primary identifier — set once before the first apply."
}

variable "kubernetes_version" {
  type        = string
  default     = "1.33"
  description = "EKS control-plane Kubernetes version. AWS retires versions ~14 months after K8s release."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID from the shared layer. Threaded in via terraform_remote_state."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs the cluster + node group attach to. Two AZs minimum."
}

variable "node_count" {
  type        = number
  default     = 2
  description = "Desired worker node count for the managed node group."
}

variable "node_min_size" {
  type        = number
  default     = 1
  description = "Minimum worker node count."
}

variable "node_max_size" {
  type        = number
  default     = 4
  description = "Maximum worker node count."
}

variable "instance_type" {
  type        = string
  default     = "t3.medium"
  description = "EC2 instance type for worker nodes."
}
