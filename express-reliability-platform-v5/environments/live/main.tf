variable "vpc_id" {
  description = "VPC ID where resources will be deployed"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "environment_name" {
  description = "Environment name"
  type        = string
}

provider "aws" {
  region = var.region
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

resource "aws_instance" "fintech" {
  ami           = "ami-0c94855ba95c71c99"
  instance_type = "t3.micro"
  tags = {
    Name        = "express-reliability-platform-fintech-${var.environment_name}"
    Environment = var.environment_name
  }
}

resource "aws_instance" "hospital" {
  ami           = "ami-0c94855ba95c71c99"
  instance_type = "t3.micro"
  tags = {
    Name        = "express-reliability-platform-hospital-${var.environment_name}"
    Environment = var.environment_name
  }
}

resource "aws_instance" "ui" {
  ami                    = "ami-0c94855ba95c71c99"
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.ui_sg.id]
  tags = {
    Name        = "express-reliability-platform-ui-${var.environment_name}"
    Environment = var.environment_name
  }
}

resource "aws_elb" "ui_elb" {
  name               = "express-reliability-platform-ui-elb-${var.environment_name}"
  availability_zones = ["us-east-1a"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  instances = [aws_instance.ui.id]
}

output "ui_portal_url" {
  value       = aws_elb.ui_elb.dns_name
  description = "URL to access the UI portal for fintech and hospital services."
}
