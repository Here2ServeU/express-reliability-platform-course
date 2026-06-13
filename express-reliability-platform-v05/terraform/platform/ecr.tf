resource "aws_ecr_repository" "services" {
  for_each     = toset(["flask-api", "node-api", "web-ui"])
  name         = "reliability-platform/${each.key}"
  force_delete = true
}
