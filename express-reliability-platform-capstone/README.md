# Express Reliability Platform: Capstone

## Purpose

The capstone is the final project from the Word guide. It integrates all ten learning versions into
one deployable, documented enterprise reliability platform.

## Goal

Clone the capstone repository, deploy the complete platform from scratch with one script, run the chaos
suite while auto-recovery is active, write the portfolio README, confirm all eight validation checks,
and push the finished project to GitHub.

## Prerequisites

Before deploying the capstone, confirm:

- [ ] **Terraform ≥ 1.5, kubectl ≥ 1.29, helm ≥ 3.14, AWS CLI v2, and Node.js 18+** installed.
- [ ] **Docker Desktop is running** — verify: `docker ps`.
- [ ] **AWS CLI v2 configured** with credentials for EKS, IAM, EC2, ECR, S3, and DynamoDB — verify: `aws sts get-caller-identity`.
- [ ] **Make the helper scripts executable** (one time):
  ```sh
  chmod +x scripts/*.sh
  ```

## Project Structure

```text
express-reliability-platform-capstone/
├── apps/
│   ├── flask-api/
│   ├── node-api/
│   └── web-ui/
├── platform/
│   ├── helm/
│   └── terraform/
├── governance/
│   ├── gatekeeper/templates/
│   ├── gatekeeper/constraints/
│   └── namespaces/
├── incident/
│   ├── slack_alert.sh
│   ├── servicenow_ticket.sh
│   ├── jira_issue.sh
│   └── postmortem.sh
├── chaos/
│   └── run_chaos_drill.sh
├── automation/
│   ├── fix_crashloop.sh
│   ├── fix_memory_pressure.sh
│   ├── fix_unreachable.sh
│   └── recovery_policy.sh
├── monitoring/
│   ├── prometheus.yml
│   ├── alert.rules.yml
│   ├── alertmanager/
│   └── grafana-dashboard*.json
├── scripts/
│   ├── deploy_capstone.sh
│   ├── build_push_images.sh
│   ├── chaos_suite.sh
│   └── cleanup_capstone.sh
├── docs/
└── README.md
```

## Run Steps

Set required environment variables:

```sh
export AWS_REGION="us-east-1"
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
export SN_INSTANCE="devXXXXXX"
export SN_USER="admin"
export SN_PASS="YOUR_SERVICENOW_PASSWORD"
export JIRA_DOMAIN="your-domain.atlassian.net"
export JIRA_EMAIL="your@email.com"
export JIRA_API_TOKEN="YOUR_JIRA_API_TOKEN"
```

Deploy:

```sh
./scripts/deploy_capstone.sh
```

Run auto-recovery in one terminal:

```sh
INTERVAL_SECONDS=30 ./automation/recovery_policy.sh
```

Run the chaos suite in another terminal:

```sh
./scripts/chaos_suite.sh
```

Clean up:

```sh
./scripts/cleanup_capstone.sh
```

## Eight Validation Checks

- [ ] Capstone repository contains `apps/`, `platform/`, `governance/`, `incident/`, `chaos/`, `automation/`, `monitoring/`, `scripts/`, and `docs/`.
- [ ] `scripts/deploy_capstone.sh` runs or delegates the full deployment workflow.
- [ ] Application pods reach Running state.
- [ ] Governance policies apply successfully.
- [ ] Monitoring targets are available.
- [ ] Slack, ServiceNow, and Jira scripts run in real or dry-run mode.
- [ ] Chaos suite records evidence.
- [ ] Auto-recovery scripts execute and report recovery actions.
