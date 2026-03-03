provider "aws" {
  region = var.region
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = "express-reliability-platform-eks-${var.environment_name}"
  cluster_version = "1.29"
  control_plane_subnet_ids = var.subnet_ids
  subnet_ids      = var.subnet_ids
  vpc_id          = var.vpc_id
  eks_managed_node_groups = {
    default = {
      desired_size = 2
      max_size     = 3
      min_size     = 1
      instance_types   = ["t3.medium"]
      capacity_type    = "SPOT"
      tags = {
        Name        = "express-reliability-platform-node-${var.environment_name}"
        Environment = var.environment_name
      }
    }
  }
  tags = {
    Environment = var.environment_name
  }
}

resource "aws_security_group" "ui_sg" {
  name        = "express-reliability-platform-ui-sg-${var.environment_name}"
  description = "Allow HTTP access to UI portal"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "alb_ingress" {
  source          = "terraform-aws-modules/alb/aws"
  name            = "express-reliability-platform-ui-alb-${var.environment_name}"
  vpc_id          = var.vpc_id
  subnets         = var.subnet_ids
  security_groups = [aws_security_group.ui_sg.id]
  internal        = false
  listeners = [{
    port     = 80
    protocol = "HTTP"
    default_action = {
      type             = "forward"
      target_group_arn = module.eks.eks_managed_node_groups["default"].target_group_arn
    }
  }]
  tags = {
    Environment = var.environment_name
  }
}

# Kubernetes resources (to be deployed via Helm)
# Helm charts for fintech, hospital, and UI portal should be installed after EKS is provisioned.
# See README for Helm deployment steps.
