locals {
  account_id = data.aws_caller_identity.current.account_id
  ecr_base   = "${local.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.project_name}"
}

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  tags = {
    Name      = "${var.project_name}-cluster"
    ManagedBy = "terraform"
  }
}

resource "aws_cloudwatch_log_group" "services" {
  for_each = toset(var.services)

  name              = "/ecs/${var.project_name}/${each.key}"
  retention_in_days = 7

  tags = {
    Service = each.key
  }
}

locals {
  service_ports = {
    "flask-api" = 5000
    "node-api"  = 3000
    "web-ui"    = 80
  }
}

resource "aws_ecs_task_definition" "services" {
  for_each = toset(var.services)

  family                   = "${each.key}-v4"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.ecs_exec.arn

  container_definitions = jsonencode([{
    name      = each.key
    image     = "${local.ecr_base}/${each.key}:latest"
    essential = true
    portMappings = [{
      containerPort = local.service_ports[each.key]
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/${var.project_name}/${each.key}"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])

  tags = {
    Service   = each.key
    ManagedBy = "terraform"
  }
}
