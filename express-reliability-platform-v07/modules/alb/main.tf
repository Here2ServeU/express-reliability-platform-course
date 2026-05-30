module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "9.7.0"
  name    = var.name
  vpc_id  = var.vpc_id
  subnets = var.subnets
  # ...other config...
}
