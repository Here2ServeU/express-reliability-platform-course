variable "aws_region" {
  default = "us-east-1"
}

variable "project_name" {
  default = "reliability-platform"
}

variable "vpc_cidr" {
  default = "10.42.0.0/16"
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

# Option 2 toggle: when true, Terraform itself builds, tags, and pushes the
# service images via the kreuzwerker/docker provider (see images.tf). When
# false (the default), images are pushed by scripts/build_push_images.sh
# before `terraform apply` runs.
variable "build_images" {
  type        = bool
  default     = false
  description = "Set to true to build/tag/push images via Terraform instead of the bash script."
}

variable "image_tag" {
  type        = string
  default     = "latest"
  description = "Tag applied to images built by Terraform when build_images = true."
}
