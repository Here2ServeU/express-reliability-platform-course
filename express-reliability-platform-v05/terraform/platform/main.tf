terraform {
  required_version = ">= 1.5"
  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 5.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.0" }
    helm       = { source = "hashicorp/helm", version = "~> 2.0" }
    http       = { source = "hashicorp/http", version = "~> 3.0" }
    tls        = { source = "hashicorp/tls", version = "~> 4.0" }
  }
  backend "s3" {
    # Reuse the bootstrap bucket from V4
    bucket         = "reliability-platform-tfstate-730335276920"
    key            = "v5/platform/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "reliability-platform-tfstate-lock"
  }
}

provider "aws" { region = var.region }

# After the cluster exists, Kubernetes and Helm providers connect to it
provider "kubernetes" {
  host                   = aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.main.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}
