terraform {
  required_version = ">= 1.5"

  required_providers {
    # The caller passes `providers = { aws = aws.untagged }` (an aws provider
    # config without default_tags) so this module's aws_budgets_budget
    # doesn't call budgets:TagResource — the course IAM user lacks that
    # permission. See ../../eks/main.tf for the alias declaration.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
