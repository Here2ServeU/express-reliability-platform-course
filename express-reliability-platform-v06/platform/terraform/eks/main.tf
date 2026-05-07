###############################################################################
# V6 root composition.
#
# This file is intentionally thin — every meaningful resource lives in a
# module under ../modules/. The root just wires modules together and sets
# the default_tags that FinOps/cost reports rely on.
#
# State key is parameterized per environment via -backend-config at init time
# (see scripts/tf_deploy_v6.sh). One state file per env keeps dev/prod from
# fighting over the same lock.
###############################################################################

terraform {
  required_version = ">= 1.5"

  backend "s3" {
    # Bucket / dynamodb_table / region / key are all supplied via
    # -backend-config flags from scripts/tf_deploy_v6.sh. Hardcoding is
    # avoided so the same root works for dev, staging, and prod.
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Single source of truth for tags applied to every taggable AWS resource.
# default_tags are merged with per-resource tags inside each module — so the
# modules don't need to know about Environment, Owner, or CostCenter at all.
# This is the canonical FinOps tagging pattern: tag once at the provider, get
# it on everything Terraform creates.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      App         = var.project_name
      Environment = var.environment
      Owner       = var.owner
      CostCenter  = var.cost_center
      Version     = var.version_suffix
      ManagedBy   = "terraform"
    }
  }
}

# Aliased provider with no default_tags. Used for AWS services whose tagging
# requires a separate IAM permission (e.g. budgets:TagResource) that the
# course's least-privilege user doesn't have. The default_tags block above
# would otherwise cause CreateBudget to call TagResource and fail with
# AccessDeniedException. Resources created via this alias get no tags from
# Terraform; the budget's filter logic uses the cost_filter_tags it was
# *given* (Environment, App), which is independent of tags on the budget
# itself.
provider "aws" {
  alias  = "untagged"
  region = var.aws_region
}

# Naming prefix used by modules for VPC / IAM / cluster names. Includes env
# so every env gets its own IAM roles and cluster — IAM is account-global, so
# without the env suffix two stacks in the same account would collide.
locals {
  name_prefix  = "${var.project_name}-${var.version_suffix}-${var.environment}"
  cluster_name = "${var.project_name}-${var.environment}"
}

module "vpc" {
  source = "../modules/vpc"

  name_prefix  = local.name_prefix
  cidr_block   = var.vpc_cidr
  cluster_name = local.cluster_name
}

module "eks_iam" {
  source = "../modules/eks-iam"

  name_prefix = local.name_prefix
}

module "eks_cluster" {
  source = "../modules/eks-cluster"

  cluster_name        = local.cluster_name
  kubernetes_version  = var.kubernetes_version
  subnet_ids          = module.vpc.public_subnet_ids
  cluster_role_arn    = module.eks_iam.cluster_role_arn
  node_role_arn       = module.eks_iam.node_role_arn
  node_group_name     = "${local.name_prefix}-workers"
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size

  # IAM policy attachments must exist before EKS calls AssumeRole on them.
  # Module-level depends_on covers all of eks_iam's resources, including the
  # policy attachments that don't appear in the cluster's data flow.
  depends_on = [module.eks_iam]
}

module "budget" {
  source = "../modules/budget"

  # Use the untagged provider so CreateBudget doesn't call TagResource —
  # see the aws.untagged provider block above for why.
  providers = {
    aws = aws.untagged
  }

  name              = "${local.name_prefix}-monthly"
  monthly_limit_usd = var.monthly_budget_usd
  alert_email       = var.budget_alert_email

  # Scope the budget to this stack's spend by tag. Requires the Environment
  # and App tags to be activated as Cost Allocation Tags in the Billing
  # console (one-time, account-global). Until activated, this filter matches
  # nothing — see modules/budget/main.tf for the full caveat.
  cost_filter_tags = {
    Environment = var.environment
    App         = var.project_name
  }
}

# ----------------------------------------------------------------------------
# Outputs
# ----------------------------------------------------------------------------

output "cluster_name" {
  value       = module.eks_cluster.cluster_name
  description = "EKS cluster name. Feed to `aws eks update-kubeconfig`."
}

output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "VPC the cluster runs in."
}

output "environment" {
  value       = var.environment
  description = "Environment this stack represents."
}

output "monthly_budget_usd" {
  value       = var.monthly_budget_usd
  description = "Monthly budget cap (USD) — alerts fire at 80% and 100%."
}
