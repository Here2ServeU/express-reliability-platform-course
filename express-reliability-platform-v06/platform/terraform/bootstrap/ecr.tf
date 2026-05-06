# ECR repos live in bootstrap (not the eks stack) because images must be
# pushed before the eks apply runs Helm — and Helm install pulls them. Keeping
# this in bootstrap means: bootstrap → repos exist → push images → eks apply
# → Helm install pulls cleanly. No -target= dance, no chicken-and-egg.
resource "aws_ecr_repository" "services" {
  for_each = toset(var.services)

  name                 = "${var.project_name}/${each.key}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name    = each.key
    Project = var.project_name
    Version = var.version_suffix
  }
}

resource "aws_ecr_lifecycle_policy" "keep_ten" {
  for_each = aws_ecr_repository.services

  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep 10 most recent images per tag"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

output "ecr_base_uri" {
  value = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.project_name}"
}

output "ecr_urls" {
  value = { for k, v in aws_ecr_repository.services : k => v.repository_url }
}
