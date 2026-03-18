# Express Reliability Platform Course

This repository is a complete training system for building AI-driven, reliable, and secure platforms for enterprise environments.

Target environments include:

- FinTech systems
- Healthcare systems
- Government and regulated systems

## Core Training Principle

Every chapter and version uses this model:

`Understand -> Build -> Test -> Break -> Fix -> Explain -> Automate -> Improve`

This model is the fastest path from beginner execution to senior engineering behavior.

## Course Map (Book Chapters -> Platform Versions)

| Version Folder | Book Coverage | Focus |
|---|---|---|
| `express-reliability-platform-v01` | Chapters 1-3 | Local foundation |
| `express-reliability-platform-v02` | Chapters 4-5 | Containerized platform |
| `express-reliability-platform-v03` | Chapters 6-8 | Terraform + IAM/OIDC + ECS |
| `express-reliability-platform-v04` | Chapters 9-10 | Observability foundations |
| `express-reliability-platform-v05` | Chapters 11-12 | Kubernetes/EKS foundations |
| `express-reliability-platform-v06` | Chapter 13 | Terraform discipline + environment promotion |
| `express-reliability-platform-v07` | Chapters 14-15 | Incident response + chaos engineering |
| `express-reliability-platform-v08` | Chapter 16 | AIOps incident-management workflow |
| `express-reliability-platform-v09` | Chapters 17-18 | Slack alerting + ITSM integration + advanced chaos |
| `express-reliability-platform-v10` | Phase 5 extension | Automation and recovery at scale |
| `express-reliability-platform-capstone` | Final integrated reference | Golden platform for interviews and client delivery |

## Phase-Based Architecture

### Phase 1 - Foundations (Versions 1-3)

- Docker and Docker Compose
- AWS foundations and IAM basics
- Terraform and ECS

### Phase 2 - Observability (Versions 4-6)

- Prometheus, Grafana, Alertmanager
- SLI/SLO and alert strategy
- health and reliability monitoring

### Phase 3 - Deep Visibility (Versions 7-8)

- runbooks and incident workflow
- chaos engineering drills
- tracing, structured logs, root-cause flow

### Phase 4 - Intelligence (Version 9)

- Slack Incoming Webhook alerting tied to AIOps risk scoring
- ITSM automation: ServiceNow incident tickets and Jira issues from evidence JSON
- Advanced chaos engineering: full pipeline drills (inject → score → alert → ticket)
- Python-based simulation and anomaly detection

### Phase 5 - Automation (Version 10)

- script-driven incident response
- auto-remediation
- recovery validation

## Enterprise Tool Stack

- DevOps: GitHub/GitLab, CI/CD, Docker
- Cloud: AWS (primary), Azure, Google Cloud
- IaC: Terraform modules, environment promotion
- Orchestration: Docker Compose, Kubernetes, EKS
- GitOps: ArgoCD
- DevSecOps: IAM, secrets, OPA/Sentinel concepts, Trivy, Checkov
- Observability: Prometheus, Grafana, Loki, Jaeger, OpenTelemetry
- Alerting: Slack Incoming Webhooks
- ITSM: ServiceNow (incident table REST API), Jira (REST API v3)
- FinOps: cost and usage optimization
- AIOps: anomaly detection, risk scoring, AI summaries, decision support
- Chaos Engineering: controlled failure injection, blast radius testing, pipeline drills

## How to Use This Repository

1. Start at `express-reliability-platform-v01`.
2. Complete versions in order.
3. Keep Docker Compose as your mandatory local gate in every version.
4. Promote to cloud in order: `dev -> staging -> prod`.
5. For each version, follow the cycle: Understand, Build, Test, Break, Fix, Explain, Automate.
6. Keep evidence for each drill (what failed, why, what fixed it).

## Build Progression Model

Do not rebuild from zero.

For each new version:

1. Copy previous version from your personal repository.
2. Improve it.
3. Extend with one new capability.

Example:

```sh
git clone https://github.com/YOUR_USERNAME/express-reliability-platform-v0X.git
mv express-reliability-platform-v0X express-reliability-platform-v0Y
cd express-reliability-platform-v0Y
```

## Scripts and Canonical Structure

Use this curriculum repository as the source of truth for scripts and structure:

- https://github.com/Here2ServeU/express-reliability-platform-course

If a file is missing in your personal repository, copy it from the matching version here.

## Daily Training System

1. Read: 15 minutes
2. Build: 60-90 minutes
3. Break: 15 minutes
4. Fix: 30 minutes
5. Document: 10 minutes

## Outcomes

By the end, you should be able to:

- design distributed systems
- deploy secure cloud workloads
- observe and debug complex incidents
- automate recovery workflows
- build AI-assisted operations

## Career Impact

This training prepares you for:

- Senior DevOps Engineer
- SRE Engineer
- Cloud Engineer
- DevSecOps Engineer

## Detailed Training Guide

Read the complete training framework in:

- [TRAINING_APPROACH.md](TRAINING_APPROACH.md)

## License

This repository is licensed under [LICENSE](LICENSE).
