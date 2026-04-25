variable "aws_region" {
  default = "us-east-1"
}

variable "project_name" {
  default = "reliability-platform"
}

variable "services" {
  default = ["node-api", "flask-api", "web-ui"]
}

variable "cpu" {
  default = "256"
}

variable "memory" {
  default = "512"
}
