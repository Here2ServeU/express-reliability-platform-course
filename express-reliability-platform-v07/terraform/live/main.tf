terraform {
  backend "s3" {
    bucket         = "reliability-platform-tfstate-YOUR_ACCOUNT_ID"
    key            = "live/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Read outputs from the shared layer state file in S3.
data "terraform_remote_state" "shared" {
  backend = "s3"

  config = {
    bucket = "reliability-platform-tfstate-YOUR_ACCOUNT_ID"
    key    = "shared/terraform.tfstate"
    region = "us-east-1"
  }
}

module "eks" {
  source = "../modules/eks"

  cluster_name  = "reliability-platform-cluster"
  vpc_id        = data.terraform_remote_state.shared.outputs.vpc_id
  subnet_ids    = data.terraform_remote_state.shared.outputs.private_subnet_ids
  node_count    = 2
  instance_type = "t3.medium"
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}
