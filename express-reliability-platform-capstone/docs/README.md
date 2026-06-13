# Express Reliability Platform — Capstone

A complete, enterprise-grade reliability platform built from scratch on AWS EKS.
It runs three microservices, monitors itself, alerts and opens incidents
automatically, heals itself, and proves its resilience through a chaos suite.
This is the integrated reference platform that combines everything from V1 to V10.

Built by: [YOUR NAME]
Cluster: AWS EKS  Region: [YOUR REGION]
GitHub: https://github.com/[YOUR_USERNAME]/express-reliability-platform-capstone

## 1. What This Platform Does

- Runs three microservices on EKS (flask-api, node-api, web-ui)
- Monitors itself with Prometheus and Grafana (real-time golden-signal dashboards)
- Alerts via Slack within seconds of an anomaly
- Creates ServiceNow incidents and Jira issues automatically
- Generates a structured postmortem for every incident
- Heals itself for three failure modes without human intervention
- Passes the chaos suite: all four drills within SLO ([YOUR MTTR]s avg)
- Enforces governance with OPA Gatekeeper, Trivy, and Checkov in CI/CD

## 2. Architecture

```
Browser → web-ui (Nginx) → node-api (Node.js) → flask-api (Python risk scorer)
```

- Kubernetes (EKS) runs every service with liveness/readiness probes and HPA.
- Prometheus scrapes /metrics; Grafana renders the golden-signal dashboards.
- Alertmanager routes alerts to Slack; incident scripts open ServiceNow + Jira.
- automation/recovery_policy.sh watches the cluster and fixes failures automatically.
- GitHub Actions deploys via OIDC with no stored AWS keys.

## 3. The Ten Versions Behind This Capstone

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

## 4. Tool Stack

- Languages/Frameworks: Node.js + Express, Python + Flask, Nginx
- Containers/Orchestration: Docker, Kubernetes (EKS), Helm
- Infrastructure as Code: Terraform (bootstrap / shared / live layers, reusable EKS module)
- CI/CD: GitHub Actions with OIDC (no stored AWS keys)
- Observability: Prometheus, Grafana, Alertmanager
- Governance: OPA Gatekeeper, Trivy, Checkov, AIOps risk scoring
- Incident pipeline: Slack, ServiceNow, Jira, automated postmortems
- Self-healing: recovery_policy.sh + fix_crashloop / fix_memory_pressure / fix_unreachable

## 5. How to Deploy

```bash
git clone https://github.com/[YOUR_USERNAME]/express-reliability-platform-capstone.git
cd express-reliability-platform-capstone

export SLACK_WEBHOOK_URL="YOUR_URL"
export SN_INSTANCE="devXXXXXX" && export SN_USER="admin" && export SN_PASS="YOUR_PASS"
export JIRA_DOMAIN="your-domain.atlassian.net" && export JIRA_EMAIL="your@email" && export JIRA_API_TOKEN="YOUR_TOKEN"

# One command brings up the entire platform (bootstrap → images → shared → live → helm → governance → monitoring)
./scripts/deploy_capstone.sh

# Run the chaos suite once the platform is healthy
./scripts/chaos_suite.sh

# Tear everything down when you are done
./scripts/cleanup_capstone.sh
```

## 6. Chaos Suite Results

| Drill | Failure Injected      | Recovery Time | SLO  | Result |
|-------|-----------------------|---------------|------|--------|
| 1     | Pod kill (flask-api)  | [X]s          | 60s  | PASSED |
| 2     | Node drain            | [X]s          | 120s | PASSED |
| 3     | CPU pressure (HPA)    | [X]s          | 90s  | PASSED |
| 4     | Crash loop simulation | [X]s          | 60s  | PASSED |

All drills run with automation/recovery_policy.sh active.
Mean MTTR: [YOUR AVERAGE]s

## 7. Interview Answer

"I built a complete reliability platform from scratch on AWS EKS. It runs three
microservices, monitors itself with Prometheus and Grafana, and alerts to Slack
within seconds. When something breaks it opens a ServiceNow incident and a Jira
issue automatically, then heals itself for crash loops, memory pressure, and
unreachable services without a human. I proved the resilience with a four-drill
chaos suite — mean MTTR was [X] seconds, every drill inside SLO.
Repo: https://github.com/[YOUR_USERNAME]/express-reliability-platform-capstone"
