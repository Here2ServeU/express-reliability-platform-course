terraform {
  backend "s3" {
    bucket         = "reliability-platform-tfstate-YOUR_ACCOUNT_ID"
    key            = "platform/v5/terraform.tfstate"
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
  region = var.aws_region
}
