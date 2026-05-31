output "budget_name" {
  value       = aws_budgets_budget.monthly.name
  description = "Name of the created budget — visible in the AWS Billing console."
}

output "budget_id" {
  value       = aws_budgets_budget.monthly.id
  description = "AWS Budgets resource ID."
}
