# Express Reliability Platform

A complete enterprise-grade reliability platform built from scratch on AWS EKS.
Demonstrates the skills required for DevOps Engineer, SRE, and Platform Engineer roles.

## What This Platform Does

- Runs three microservices on EKS (flask-api, node-api, web-ui)
- Monitors itself with Prometheus and Grafana (real-time dashboards)
- Alerts via Slack within seconds of an anomaly
- Creates ServiceNow incidents and Jira issues automatically
- Heals itself for three failure modes without human intervention
- Passes chaos suite: all four drills within SLO ([YOUR MTTR]s avg)

Built by: [YOUR NAME]
Cluster: AWS EKS  Region: [YOUR REGION]
GitHub: https://github.com/[YOUR_USERNAME]/express-reliability-platform-v10

## Architecture

Browser → web-ui (Nginx) → node-api (Node.js) → flask-api (Python risk scorer)

- Kubernetes (EKS) runs every service with liveness/readiness probes and HPA.
- Prometheus scrapes /metrics; Grafana renders the golden-signal dashboards.
- Alertmanager routes alerts to Slack; incident scripts open ServiceNow + Jira.
- automation/recovery_policy.sh watches the cluster and fixes failures automatically.

## All 10 Versions

| Version | Title | Key Addition |
|---------|-------|--------------|
| V1  | Your First Web Service       | Node.js, Express, Git, GitHub |
| V2  | Three Services, One Platform | Docker, Flask, Docker Compose, Nginx |
| V3  | Your First AWS Deployment    | ECR, ECS, Fargate, IAM, VPC, OIDC |
| V4  | Monitoring + Terraform       | Prometheus, Grafana, Alertmanager |
| V5  | Kubernetes on EKS            | EKS, kubectl, HPA, Liveness Probes, Helm |
| V6  | Terraform Modules            | Modules, tfvars, AWS Budgets, Helm charts |
| V7  | Layer Separation + CI/CD     | Shared/live layers, GitHub Actions, OIDC |
| V8  | GitOps + Governance          | OPA Gatekeeper, Trivy, Risk Scoring |
| V9  | Incident Pipeline            | Slack, ServiceNow, Jira, Chaos drills |
| V10 | Self-Healing Automation      | Recovery policy, Chaos suite |

## Tool Stack

- Languages/Frameworks: Node.js + Express, Python + Flask, Nginx
- Containers/Orchestration: Docker, Kubernetes (EKS), Helm
- Infrastructure as Code: Terraform (shared/live layers, reusable EKS module)
- CI/CD: GitHub Actions with OIDC (no stored AWS keys)
- Observability: Prometheus, Grafana, Alertmanager
- Governance: OPA Gatekeeper, Trivy, Checkov, AIOps risk scoring
- Incident pipeline: Slack, ServiceNow, Jira, automated postmortems
- Self-healing: recovery_policy.sh + fix_crashloop / fix_memory_pressure / fix_unreachable

## How to Deploy

```bash
git clone https://github.com/[YOUR_USERNAME]/express-reliability-platform-v10.git
cd express-reliability-platform-v10

export SLACK_WEBHOOK_URL="YOUR_URL"
export SN_INSTANCE="devXXXXXX" && export SN_USER="admin" && export SN_PASS="YOUR_PASS"
export JIRA_DOMAIN="your-domain.atlassian.net" && export JIRA_EMAIL="your@email" && export JIRA_API_TOKEN="YOUR_TOKEN"

./scripts/tf_deploy_v10.sh
```

## Chaos Suite Results

| Drill | Failure Injected      | Recovery Time | SLO  | Result |
|-------|-----------------------|---------------|------|--------|
| 1     | Pod kill (flask-api)  | [X]s          | 60s  | PASSED |
| 2     | Node drain            | [X]s          | 120s | PASSED |
| 3     | CPU pressure (HPA)    | [X]s          | 90s  | PASSED |
| 4     | Crash loop simulation | [X]s          | 60s  | PASSED |

All drills run with automation/recovery_policy.sh active.
Mean MTTR: [YOUR AVERAGE]s

## Interview Answer

I built a complete reliability platform from scratch on AWS EKS.
It monitors itself, heals itself, and proves resilience through chaos engineering.
Mean MTTR: [X]s across four failure modes.
Repo: https://github.com/[YOUR_USERNAME]/express-reliability-platform-v10
