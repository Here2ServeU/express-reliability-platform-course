variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region the EKS cluster lives in. Must match the shared layer region."
}

variable "state_bucket" {
  type        = string
  default     = "reliability-platform-v07-tfstate-YOUR_ACCOUNT_ID"
  description = "S3 bucket holding both shared and live state. tf_deploy_v7.sh overrides this with the real bucket name from bootstrap output. Replace YOUR_ACCOUNT_ID for plain `terraform apply` to work standalone."
}

variable "cluster_name" {
  type        = string
  default     = "reliability-platform-cluster"
  description = "EKS cluster name. Must match the cluster_name passed to the shared layer so the subnet discovery tags line up."
}

variable "kubernetes_version" {
  type        = string
  default     = "1.33"
  description = "EKS control-plane Kubernetes version. AWS retires versions ~14 months after K8s release — bump as needed."
}

variable "node_instance_type" {
  type        = string
  default     = "t3.medium"
  description = "EC2 instance type for the EKS managed node group."
}

variable "node_desired_size" {
  type        = number
  default     = 2
  description = "Desired worker node count. Two nodes are the V7 default — enough for three Helm releases with two replicas each."
}

variable "node_min_size" {
  type        = number
  default     = 1
  description = "Minimum worker node count for the managed node group."
}

variable "node_max_size" {
  type        = number
  default     = 4
  description = "Maximum worker node count. Bump if you scale a Deployment past 4 replicas."
}
