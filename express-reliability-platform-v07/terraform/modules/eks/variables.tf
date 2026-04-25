variable "cluster_name" {
  description = "Name for the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID from shared layer"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for nodes"
  type        = list(string)
}

variable "node_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

variable "instance_type" {
  description = "EC2 instance type for nodes"
  type        = string
  default     = "t3.medium"
}
