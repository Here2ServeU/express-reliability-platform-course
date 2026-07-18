variable "name" {
  type        = string
  description = "Budget name. Include env so dev and prod budgets don't collide (AWS Budgets are unique per account)."
}

variable "monthly_limit_usd" {
  type        = number
  description = "Monthly spending limit in USD. Below the alert thresholds, no email is sent; over them, an email goes to alert_email."

  validation {
    condition     = var.monthly_limit_usd > 0
    error_message = "monthly_limit_usd must be greater than 0."
  }
}

variable "alert_email" {
  type        = string
  description = "Email address that receives budget alerts. The first alert from a new account triggers an SES bounce-test, so the address must be deliverable."

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email))
    error_message = "alert_email must look like name@example.com."
  }
}

variable "alert_thresholds_percent" {
  type        = list(number)
  default     = [80, 100]
  description = "Spend-percentage thresholds at which an alert fires. 80/100 means: warn at 80% of monthly limit, alert again at 100%."
}

variable "cost_filter_tags" {
  type        = map(string)
  default     = {}
  description = "Optional tag filters that scope the budget. Example: { Environment = \"dev\", App = \"reliability-platform\" } limits the budget to spend on resources carrying both tags. Empty map = whole-account budget."
}
