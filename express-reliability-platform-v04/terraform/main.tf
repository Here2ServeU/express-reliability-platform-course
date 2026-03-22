# =============================================================================
# Express Reliability Platform V4 — Terraform: AWS Monitoring Extension
# Chapter 14: Basic Monitoring in AWS
#
# Purpose:
#   This file extends the local observability stack (Prometheus + Grafana)
#   into AWS by declaring the infrastructure needed to run services on ECS
#   and send logs and metrics to CloudWatch.
#
# What each block does:
#   - terraform / provider    : lock provider versions and set the AWS region
#   - variables               : inputs you override per environment
#   - aws_cloudwatch_log_group: central log destination for every ECS container
#   - aws_ecs_cluster         : logical boundary grouping all ECS services
#   - aws_cloudwatch_metric_alarm (x2): fire alerts when error count or CPU is high
#
# How to use:
#   terraform init            # download provider plugins
#   terraform plan            # preview what will be created
#   terraform apply           # create resources in AWS
#   terraform destroy         # tear everything down when done
# =============================================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------

variable "region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment name (dev | staging | prod)"
  type        = string
  default     = "dev"
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs before expiry"
  type        = number
  default     = 14
}

variable "alarm_email" {
  description = "Email address to receive CloudWatch alarm notifications"
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# CloudWatch Log Group
# All ECS tasks write stdout / stderr here via the awslogs driver.
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "platform" {
  name              = "/ecs/express-reliability-platform-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = {
    Environment = var.environment
    Project     = "express-reliability-platform"
  }
}

# ---------------------------------------------------------------------------
# ECS Cluster
# Logical grouping for all platform services (node-api, flask-api, web-ui).
# Actual task definitions and services are added in V5 when ECS deployment
# is introduced. This block creates the cluster so it is ready to receive them.
# ---------------------------------------------------------------------------

resource "aws_ecs_cluster" "platform" {
  name = "express-reliability-platform-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "enabled" # publishes per-container CPU / memory metrics to CloudWatch
  }

  tags = {
    Environment = var.environment
    Project     = "express-reliability-platform"
  }
}

# ---------------------------------------------------------------------------
# CloudWatch Metric Alarms
# These fire when the platform breaches reliability thresholds.
# Notifications are sent to the SNS topic below if alarm_email is set.
# ---------------------------------------------------------------------------

# SNS topic — receives alarm notifications
resource "aws_sns_topic" "alerts" {
  name = "express-reliability-platform-alerts-${var.environment}"
}

# Subscribe the provided email address to the alerts topic
resource "aws_sns_topic_subscription" "email" {
  count     = var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# Alarm 1 — High HTTP error count on node-api
# Trigger: more than 10 HTTP 5xx errors in any 5-minute window
resource "aws_cloudwatch_metric_alarm" "node_api_high_errors" {
  alarm_name          = "erp-${var.environment}-node-api-high-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300 # 5 minutes
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Node API is returning more than 10 HTTP 5xx errors per 5 minutes."
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = "PLACEHOLDER_ALB_ARN_SUFFIX" # replace with real ALB suffix in V5
  }
}

# Alarm 2 — High ECS CPU utilisation across the cluster
# Trigger: average CPU exceeds 80 % for two consecutive 5-minute periods
resource "aws_cloudwatch_metric_alarm" "ecs_high_cpu" {
  alarm_name          = "erp-${var.environment}-ecs-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300 # 5 minutes
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ECS cluster average CPU has exceeded 80% for 10 minutes."
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.platform.name
  }
}

# ---------------------------------------------------------------------------
# Outputs
# Exposed so other Terraform modules (V5+) can reference these resources.
# ---------------------------------------------------------------------------

output "log_group_name" {
  description = "CloudWatch log group that ECS tasks write to"
  value       = aws_cloudwatch_log_group.platform.name
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.platform.name
}

output "alerts_topic_arn" {
  description = "SNS topic ARN for alarm notifications"
  value       = aws_sns_topic.alerts.arn
}
