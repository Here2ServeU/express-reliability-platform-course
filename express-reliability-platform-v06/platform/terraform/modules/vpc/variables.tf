variable "name_prefix" {
  type        = string
  description = "Prefix used in Name tags for VPC, IGW, subnets, route table. Usually <project>-<env>."
}

variable "cidr_block" {
  type        = string
  description = "Primary IPv4 CIDR for the VPC. /16 recommended; the module carves /24 public subnets out of it."

  validation {
    condition     = can(cidrnetmask(var.cidr_block))
    error_message = "cidr_block must be a valid IPv4 CIDR (e.g. 10.43.0.0/16)."
  }
}

variable "public_subnet_count" {
  type        = number
  default     = 2
  description = "Number of public subnets to create across distinct AZs. EKS requires at least 2."

  validation {
    condition     = var.public_subnet_count >= 2
    error_message = "EKS requires at least 2 subnets in different AZs."
  }
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name. Subnets are tagged kubernetes.io/cluster/<this>=shared so the LB controller and EKS can discover them."
}
