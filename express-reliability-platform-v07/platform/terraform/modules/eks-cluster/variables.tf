variable "cluster_name" {
  type        = string
  description = "EKS cluster name. Must match the kubernetes.io/cluster/<this> tag on the subnets passed in."
}

variable "kubernetes_version" {
  type        = string
  description = "EKS control-plane Kubernetes version (e.g. 1.33). AWS retires versions ~14 months after K8s release; bump when current default is retired."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs (>=2 in different AZs) for the EKS control plane and node group."

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "EKS requires at least 2 subnets in distinct AZs."
  }
}

variable "cluster_role_arn" {
  type        = string
  description = "ARN of the IAM role the EKS control plane assumes."
}

variable "node_role_arn" {
  type        = string
  description = "ARN of the IAM role the worker nodes assume."
}

variable "node_group_name" {
  type        = string
  default     = "workers"
  description = "Name of the managed node group."
}

variable "node_instance_types" {
  type        = list(string)
  description = "EC2 instance types for the managed node group. List allows AWS to spread the order across AZs."
}

variable "node_desired_size" {
  type        = number
  description = "Desired worker node count."
}

variable "node_min_size" {
  type        = number
  description = "Minimum worker node count."
}

variable "node_max_size" {
  type        = number
  description = "Maximum worker node count. Bump if you scale a Deployment past this."
}
