# Application Load Balancer — stable public DNS name
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name      = "${var.project_name}-alb"
    ManagedBy = "terraform"
  }
}

# Target group for web-ui
resource "aws_lb_target_group" "web_ui" {
  name        = "${var.project_name}-web-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }
}

# HTTP listener — route all traffic to web-ui
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_ui.arn
  }
}

# ECS services — keep tasks running, one per service
resource "aws_ecs_service" "services" {
  for_each = toset(var.services)

  name            = each.key
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.services[each.key].arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  dynamic "load_balancer" {
    for_each = each.key == "web-ui" ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.web_ui.arn
      container_name   = "web-ui"
      container_port   = 80
    }
  }

  # docker_registry_image.services is empty when build_images = false (Option 1,
  # bash flow), so this is a no-op. When build_images = true (Option 2) it
  # makes the ECS service wait until Terraform has pushed the image to ECR.
  depends_on = [
    aws_lb_listener.http,
    docker_registry_image.services,
  ]

  tags = {
    Service = each.key
  }
}

output "alb_dns_name" {
  value = "http://${aws_lb.main.dns_name}"
}
