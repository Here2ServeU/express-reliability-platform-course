terraform {
  backend "s3" {
    bucket         = "reliability-platform-v07-tfstate-730335276920"
    key            = "live/v7/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock-v07"
  }
  required_providers { aws = { source = "hashicorp/aws", version = "~> 5.0" } }
}

provider "aws" { region = "us-east-1" }

variable "state_bucket" { type = string }

# Read the whiteboard — shared layer's outputs from its S3 state file
data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "shared/v7/terraform.tfstate"
    region = "us-east-1"
  }
}

# Call the EKS module with VPC values from shared's whiteboard
module "eks" {
  source        = "../modules/eks"
  cluster_name  = "reliability-platform-cluster"
  vpc_id        = data.terraform_remote_state.shared.outputs.vpc_id
  subnet_ids    = data.terraform_remote_state.shared.outputs.private_subnet_ids
  node_count    = 2
  instance_type = "t3.medium"
}

output "cluster_name"     { value = module.eks.cluster_name }
output "cluster_endpoint" { value = module.eks.cluster_endpoint }
