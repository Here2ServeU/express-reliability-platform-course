###############################################################################
# Option 2 — Terraform-native build, tag, and push.
#
# When var.build_images = true, Terraform itself drives the image pipeline:
#   1. docker_image.services       → docker buildx build --platform linux/amd64
#   2. docker_registry_image.svc   → docker push to ECR
#
# When var.build_images = false (default), every resource here has an empty
# for_each so Terraform creates nothing — and students run the bash pipeline
# (scripts/build_push_images.sh, Option 1) instead.
#
# Either way the docker daemon must be running on the machine that executes
# `terraform apply`, just like the bash flow.
###############################################################################

# Short-lived ECR auth token (12-hour TTL). Always fetched so the docker
# provider has credentials wired up; harmless when build_images = false because
# no docker_* resources reference the registry.
data "aws_ecr_authorization_token" "ecr" {}

provider "docker" {
  registry_auth {
    address  = "${local.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
    username = data.aws_ecr_authorization_token.ecr.user_name
    password = data.aws_ecr_authorization_token.ecr.password
  }
}

# Build each service image locally for linux/amd64 (Fargate's runtime arch).
resource "docker_image" "services" {
  for_each = var.build_images ? toset(var.services) : toset([])

  name = "${local.ecr_base}/${each.key}:${var.image_tag}"

  build {
    context  = "${path.root}/../../apps/${each.key}"
    platform = "linux/amd64"
  }

  # Rebuild whenever any file under apps/<svc>/ changes.
  triggers = {
    dir_sha = sha1(join("", [
      for f in fileset("${path.root}/../../apps/${each.key}", "**") :
      filesha1("${path.root}/../../apps/${each.key}/${f}")
    ]))
  }

  depends_on = [aws_ecr_repository.services]
}

# Push each built image to its ECR repo.
resource "docker_registry_image" "services" {
  for_each = docker_image.services

  name          = each.value.name
  keep_remotely = true

  triggers = {
    image_id = each.value.image_id
  }

  depends_on = [aws_ecr_repository.services]
}
