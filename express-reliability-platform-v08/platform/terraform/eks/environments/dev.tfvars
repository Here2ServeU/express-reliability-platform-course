# Dev environment: sized for "small enough to leave running by accident
# without burning the budget." One small node, tight budget, alert email
# to the platform team.
environment = "dev"

# Distinct from V6 (10.43.0.0/16 dev, 10.44.0.0/16 prod) and V7 (10.45.0.0/16 dev, 10.46.0.0/16
# prod): peerable without overlaps if a later version needs cross-env
# networking.
vpc_cidr = "10.47.0.0/16"

# t3.small caps at 11 pods (ENI limit), which the system pods plus three
# 2-replica services fill exactly — rolling updates then have no room for
# surge pods and stall. t3.medium raises the cap to 17 for ~$15/mo more.
#
# CHANGED IN V8: desired_size goes 1 -> 2. V7 fit on a single t3.medium;
# V8 does not. Counting only pods that consume an ENI address (aws-node and
# kube-proxy are host-network and are free):
#
#   coredns                    2
#   flask/node/web (2 each)    6
#   monitoring stack           5   (prometheus, grafana, alertmanager,
#                                   operator, kube-state-metrics)
#   Argo CD                    6
#   Gatekeeper                 2
#   ------------------------------
#   total                     21   > 17, the cap for one t3.medium
#
# Two nodes give 34 and leave headroom for rolling-update surge pods.
# The symptom if you drop this back to 1: pods stuck Pending with
# "Too many pods" in `kubectl describe pod`.
#
# This roughly doubles dev's run rate (~$2.10/day -> ~$4.20/day). To keep
# one node, deploy with SKIP_MONITORING=true and accept that V7's Grafana
# dashboards are unavailable in-cluster (the Docker Compose stack still
# works locally, and costs nothing).
node_instance_types = ["t3.medium"]
node_desired_size   = 2
node_min_size       = 1
node_max_size       = 3

monthly_budget_usd = 50
budget_alert_email = "info@transformed2succeed.com"

owner       = "platform-team"
cost_center = "platform-eng"
