resource "aws_budgets_budget" "monthly" {
  name              = var.name
  budget_type       = "COST"
  limit_amount      = format("%.2f", var.monthly_limit_usd)
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2024-01-01_00:00"

  # Tag-based filtering only works for tags activated as Cost Allocation Tags
  # in the Billing console. Until activated, AWS treats tagged spend as
  # "untagged" and the filter matches nothing. To activate: Billing console →
  # Cost allocation tags → activate the keys you use here. Activation can take
  # ~24h to back-fill historical spend.
  dynamic "cost_filter" {
    for_each = var.cost_filter_tags
    content {
      name   = "TagKeyValue"
      values = ["${cost_filter.key}$${cost_filter.value}"]
    }
  }

  dynamic "notification" {
    for_each = toset(var.alert_thresholds_percent)
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = [var.alert_email]
    }
  }
}
