variable "cluster_name" {
  description = "Name for the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID — provided by the shared layer via remote state"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for worker nodes — private subnets from shared"
  type        = list(string)
}

variable "node_count" {
  description = "Number of EC2 worker nodes"
  type        = number
  default     = 2
}

variable "instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3.medium"
}
