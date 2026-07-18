# Dev environment: sized for "small enough to leave running by accident
# without burning the budget." One small node, tight budget, alert email
# to the platform team.
environment = "dev"

# Distinct from V5 (10.42.0.0/16) and V6 (10.43.0.0/16 dev, 10.44.0.0/16
# prod): peerable without overlaps if a later version needs cross-env
# networking.
vpc_cidr = "10.45.0.0/16"

# t3.small caps at 11 pods (ENI limit), which the system pods plus three
# 2-replica services fill exactly — rolling updates then have no room for
# surge pods and stall. t3.medium raises the cap to 17 for ~$15/mo more.
node_instance_types = ["t3.medium"]
node_desired_size   = 1
node_min_size       = 1
node_max_size       = 2

monthly_budget_usd = 50
budget_alert_email = "info@transformed2succeed.com"

owner       = "platform-team"
cost_center = "platform-eng"
