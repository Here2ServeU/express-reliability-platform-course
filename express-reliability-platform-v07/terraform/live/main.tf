terraform {
  backend "s3" {
    # Same bucket as shared, different key — that's how V7 layer-isolates state.
    # tf_deploy_v7.sh threads the real bucket in via -backend-config at init
    # time. Replace YOUR_ACCOUNT_ID for plain `terraform init` to work.
    bucket         = "reliability-platform-v07-tfstate-YOUR_ACCOUNT_ID"
    key            = "live/v7/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock-v07"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ----------------------------------------------------------------------------
# Live layer — the compute foundation.
#
# Reads the VPC + subnet IDs from `shared` via terraform_remote_state and
# launches an EKS cluster inside them. Rebuilt frequently as the platform
# iterates; cannot corrupt or destroy `shared`'s state because they live at
# different keys (shared/v7/terraform.tfstate vs live/v7/terraform.tfstate).
#
# A `terraform destroy` here removes EKS but leaves the VPC intact, so the
# next `terraform apply` re-creates the cluster in 10-15 minutes without
# rebuilding the network.
# ----------------------------------------------------------------------------

# Reads shared's outputs from its S3 state file. The bucket / key here MUST
# match shared's backend block exactly, or this returns null outputs and the
# module call fails with "vpc_id is null".
data "terraform_remote_state" "shared" {
  backend = "s3"

  config = {
    bucket = var.state_bucket
    key    = "shared/v7/terraform.tfstate"
    region = var.aws_region
  }
}

module "eks" {
  source = "../modules/eks"

  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
  vpc_id             = data.terraform_remote_state.shared.outputs.vpc_id
  # Workers run in PUBLIC subnets so they can pull from ECR without a NAT
  # gateway. Switch to `private_subnet_ids` here once you add a NAT in shared.
  subnet_ids    = data.terraform_remote_state.shared.outputs.public_subnet_ids
  node_count    = var.node_desired_size
  node_min_size = var.node_min_size
  node_max_size = var.node_max_size
  instance_type = var.node_instance_type
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_arn" {
  value = module.eks.cluster_arn
}
