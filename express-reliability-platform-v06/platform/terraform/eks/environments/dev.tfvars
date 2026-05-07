# Dev environment — sized for "small enough to leave running by accident
# without burning the budget." One small node, tight budget, alert email
# to the platform team.
environment = "dev"

# Distinct from V5's 10.42.0.0/16 and from prod's 10.44.0.0/16 — peerable
# without overlaps if a later version needs cross-env networking.
vpc_cidr = "10.43.0.0/16"

node_instance_types = ["t3.small"]
node_desired_size   = 1
node_min_size       = 1
node_max_size       = 2

monthly_budget_usd = 50
budget_alert_email = "platform-team@example.com"

owner       = "platform-team"
cost_center = "platform-eng"
