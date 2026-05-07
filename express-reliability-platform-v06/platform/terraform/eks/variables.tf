variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region. Must match the bootstrap region (state bucket lives there)."
}

# ----------------------------------------------------------------------------
# Identity / naming
# ----------------------------------------------------------------------------

variable "project_name" {
  type        = string
  default     = "reliability-platform"
  description = "Logical project name. Becomes part of resource Name tags and the App tag."
}

variable "version_suffix" {
  type        = string
  default     = "v06"
  description = "Course version. Combined with env to namespace IAM roles, the cluster, and budgets across this account."
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev, staging, prod). Drives sizing, CIDR, budget, and the Environment tag. Pass via -var-file=environments/<env>.tfvars."

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "owner" {
  type        = string
  default     = "platform-team"
  description = "Team or person responsible for the stack. Goes into the Owner tag — this is who FinOps and on-call escalate to."
}

variable "cost_center" {
  type        = string
  default     = "platform-eng"
  description = "Cost-center label for chargeback/showback reports. Goes into the CostCenter tag."
}

# ----------------------------------------------------------------------------
# Networking
# ----------------------------------------------------------------------------

variable "vpc_cidr" {
  type        = string
  description = "Primary IPv4 CIDR for the env's VPC. Pick non-overlapping CIDRs across envs so they could be peered later."
}

# ----------------------------------------------------------------------------
# EKS
# ----------------------------------------------------------------------------

variable "kubernetes_version" {
  type        = string
  default     = "1.33"
  description = "EKS control-plane Kubernetes version. AWS retires versions ~14 months after K8s release; check `aws eks describe-cluster-versions` and bump when current default is retired."
}

variable "node_instance_types" {
  type        = list(string)
  description = "Worker instance types. Smaller for non-prod (cost-aware), larger for prod (capacity)."
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
  description = "Maximum worker node count."
}

# ----------------------------------------------------------------------------
# Cost guardrails
# ----------------------------------------------------------------------------

variable "monthly_budget_usd" {
  type        = number
  description = "Per-env monthly spending cap. Email is sent when actual spend crosses 80% and 100%."
}

variable "budget_alert_email" {
  type        = string
  description = "Email that receives budget alerts. Must be deliverable — first alert from a new account triggers an SES bounce-test."
}
