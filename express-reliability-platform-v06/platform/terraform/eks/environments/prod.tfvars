# Prod environment — sized for the V5/V6 self-healing demo at realistic
# scale. Three medium nodes, room to grow to six, and a real budget so the
# alert fires before the bill surprises anyone.
environment = "prod"

# Distinct from dev (10.43.0.0/16) so the two could be peered later.
vpc_cidr = "10.44.0.0/16"

node_instance_types = ["t3.medium"]
node_desired_size   = 3
node_min_size       = 2
node_max_size       = 6

monthly_budget_usd = 300
budget_alert_email = "platform-team@example.com"

owner       = "platform-team"
cost_center = "platform-eng"
