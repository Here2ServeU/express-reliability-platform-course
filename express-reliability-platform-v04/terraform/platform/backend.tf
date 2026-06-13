terraform {
  backend "s3" {
    bucket         = "reliability-platform-tfstate-YOUR_ACCOUNT_ID"
    key            = "platform/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "reliability-platform-tfstate-lock"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
