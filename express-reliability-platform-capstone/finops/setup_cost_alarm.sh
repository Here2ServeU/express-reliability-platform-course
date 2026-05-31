#!/usr/bin/env bash
#
# FinOps — create an AWS monthly budget with email alerts.
#
# Two ways to set a budget guardrail:
#   1) Terraform (preferred, reviewable, version-controlled): finops/terraform/budget
#   2) This script (quick, imperative) using the AWS CLI.
#
# Usage:
#   ./finops/setup_cost_alarm.sh <monthly_limit_usd> <alert_email> [budget_name]
#
# Example:
#   ./finops/setup_cost_alarm.sh 200 platform-oncall@example.com express-platform-budget
#
# Dry run (print the budget JSON without creating anything):
#   DRY_RUN=1 ./finops/setup_cost_alarm.sh 200 you@example.com

set -euo pipefail

LIMIT="${1:-}"
EMAIL="${2:-}"
NAME="${3:-express-platform-budget}"
DRY_RUN="${DRY_RUN:-0}"

if [[ -z "$LIMIT" || -z "$EMAIL" ]]; then
  echo "Usage: $0 <monthly_limit_usd> <alert_email> [budget_name]" >&2
  exit 2
fi

BUDGET_JSON=$(cat <<JSON
{
  "BudgetName": "$NAME",
  "BudgetLimit": { "Amount": "$LIMIT", "Unit": "USD" },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST"
}
JSON
)

# Alert at 50%, 80%, and 100% of the monthly limit.
NOTIFICATIONS_JSON=$(cat <<JSON
[
  { "Notification": { "NotificationType": "ACTUAL", "ComparisonOperator": "GREATER_THAN", "Threshold": 50,  "ThresholdType": "PERCENTAGE" },
    "Subscribers": [ { "SubscriptionType": "EMAIL", "Address": "$EMAIL" } ] },
  { "Notification": { "NotificationType": "ACTUAL", "ComparisonOperator": "GREATER_THAN", "Threshold": 80,  "ThresholdType": "PERCENTAGE" },
    "Subscribers": [ { "SubscriptionType": "EMAIL", "Address": "$EMAIL" } ] },
  { "Notification": { "NotificationType": "ACTUAL", "ComparisonOperator": "GREATER_THAN", "Threshold": 100, "ThresholdType": "PERCENTAGE" },
    "Subscribers": [ { "SubscriptionType": "EMAIL", "Address": "$EMAIL" } ] }
]
JSON
)

echo "Budget '$NAME': \$$LIMIT/month, alerts to $EMAIL at 50/80/100%."

if [[ "$DRY_RUN" == "1" ]]; then
  echo "[dry-run] Budget payload:"
  echo "$BUDGET_JSON"
  echo "[dry-run] Notifications payload:"
  echo "$NOTIFICATIONS_JSON"
  echo "[dry-run] Would run: aws budgets create-budget ..."
  exit 0
fi

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

aws budgets create-budget \
  --account-id "$ACCOUNT_ID" \
  --budget "$BUDGET_JSON" \
  --notifications-with-subscribers "$NOTIFICATIONS_JSON"

echo "Budget '$NAME' created for account $ACCOUNT_ID."
