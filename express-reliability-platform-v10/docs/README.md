# Express Reliability Platform

A complete enterprise-grade reliability platform, built first on AWS EKS (V9) and ported to Google Cloud GKE (V10).
Demonstrates the skills required for DevOps Engineer, SRE, and Platform Engineer roles.

## What This Platform Does

- Runs three microservices on GKE (flask-api, node-api, web-ui)
- Monitors itself with Google Managed Prometheus and Cloud Monitoring SLOs (99.5% availability, 95% under 500 ms) with burn-rate alerts
- Alerts via Slack within seconds of an anomaly
- Creates ServiceNow incidents and Jira issues automatically
- Heals itself for three failure modes without human intervention
- Passes chaos suite: all five drills within SLO ([YOUR MTTR]s avg)

Built by: [YOUR NAME]
Cluster: GKE  Region: [YOUR REGION]
GitHub: https://github.com/[YOUR_USERNAME]/express-reliability-platform-v10

## Architecture

Browser → web-ui (Nginx) → node-api (Node.js) → flask-api (Python risk scorer)

- Kubernetes (GKE, private nodes, Workload Identity) runs every service with liveness/readiness probes.
- Managed Prometheus scrapes /metrics; Cloud Monitoring judges the SLOs and pages on fast error-budget burn.
- Alertmanager routes alerts to Slack; incident scripts open ServiceNow + Jira.
- automation/recovery_policy.sh watches the cluster and fixes failures automatically.

## Course Versions

| Version | Title | Key Addition |
|---------|-------|--------------|
| V1  | Your First Web Service       | Node.js, Express, Git, GitHub |
| V2  | Three Services, One Platform | Docker, Flask, Docker Compose, Nginx |
| V3  | Your First AWS Deployment    | ECR, ECS, Fargate, IAM, VPC, OIDC |
| V4  | Monitoring + Terraform       | Prometheus, Grafana, Alertmanager |
| V5  | Kubernetes on EKS            | EKS, kubectl, HPA, Liveness Probes, Helm |
| V6  | Terraform Modules            | Modules, tfvars, AWS Budgets, Helm charts |
| V7  | Layer Separation + CI/CD     | Shared/live layers, GitHub Actions, OIDC |
| V8  | Governance + Incident Pipeline | OPA Gatekeeper, Trivy, Slack, ITSM, chaos drills |
| V9  | Capstone                     | Self-healing recovery and chaos-suite evidence |
| V10 | Multi-Cloud on GKE           | GKE, Artifact Registry, Workload Identity, Cloud Monitoring SLOs |

## Tool Stack

- Languages/Frameworks: Node.js + Express, Python + Flask, Nginx
- Containers/Orchestration: Docker, Kubernetes (EKS in V9, GKE in V10), Helm
- Infrastructure as Code: Terraform (bootstrap/shared/live layers, reusable GKE module)
- CI/CD: GitHub Actions with Workload Identity Federation (no stored cloud keys)
- Observability: Google Managed Prometheus, Cloud Monitoring SLOs, burn-rate alerting
- Governance: OPA Gatekeeper, Trivy, Checkov, AIOps risk scoring
- Incident pipeline: Slack, ServiceNow, Jira, automated postmortems
- Self-healing: recovery_policy.sh + fix_crashloop / fix_memory_pressure / fix_unreachable

## How to Deploy

```bash
git clone https://github.com/[YOUR_USERNAME]/express-reliability-platform-v10.git
cd express-reliability-platform-v10

export PROJECT_ID="your-project-id"
export SLACK_WEBHOOK_URL="YOUR_URL"
export SN_INSTANCE="devXXXXXX" && export SN_USER="admin" && export SN_PASS="YOUR_PASS"
export JIRA_DOMAIN="your-domain.atlassian.net" && export JIRA_EMAIL="your@email" && export JIRA_API_TOKEN="YOUR_TOKEN"

./scripts/deploy_capstone.sh
```

## Chaos Suite Results

| Drill | Failure Injected      | Recovery Time | SLO  | Result |
|-------|-----------------------|---------------|------|--------|
| 1     | Pod kill (flask-api)  | [X]s          | 60s  | PASSED |
| 2     | Node drain            | [X]s          | 120s | PASSED |
| 3     | CPU pressure (HPA)    | [X]s          | 90s  | PASSED |
| 4     | Crash loop simulation | [X]s          | 60s  | PASSED |
| 5     | Error-budget burn     | [X]s          | 90s  | PASSED |

All drills run with automation/recovery_policy.sh active.
Mean MTTR: [YOUR AVERAGE]s

## Interview Answer

I built a complete reliability platform from scratch on AWS EKS, then ported it to GCP GKE.
Only the cloud modules changed; Helm, chaos, incident, and governance tooling stayed the same.
On GKE it runs with Workload Identity, Managed Prometheus, and Cloud Monitoring SLOs with burn-rate alerts.
Mean MTTR: [X]s across five failure modes.
Repo: https://github.com/[YOUR_USERNAME]/express-reliability-platform-v10
