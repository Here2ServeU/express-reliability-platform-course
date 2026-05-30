# Controls Matrix — Golden Platform

Use this matrix as your default baseline when implementing or assessing a regulated environment.

## 1) Identity and Access

| Control | Objective | Implementation Pattern | Evidence |
|---|---|---|---|
| Least privilege IAM | Limit blast radius | Scoped roles/policies by workload and environment | IAM policies + review log |
| Federated CI/CD identity | Remove static secrets | GitHub OIDC role assumption | Workflow runs + trust policy |
| Privileged access review | Prevent privilege creep | Scheduled access recertification | Access review records |

## 2) Change and Release Management

| Control | Objective | Implementation Pattern | Evidence |
|---|---|---|---|
| Pull request approvals | Controlled changes | Branch protection + required reviewers | PR history |
| Infrastructure as code | Traceable infra changes | Terraform plan/apply process | Plan artifacts + commit history |
| Release rollback readiness | Reduce outage duration | Documented rollback steps | Rollback drill logs |

## 3) Reliability and Operations

| Control | Objective | Implementation Pattern | Evidence |
|---|---|---|---|
| SLO/SLI ownership | Objective reliability goals | Service-level SLO catalog | SLO document + dashboards |
| Alert quality | Actionable notifications | Severity mapping + threshold tuning | Alert rule exports |
| Incident runbooks | Faster mean time to recover | Standard response playbooks | Runbook repo + drill evidence |

## 4) Data Protection

| Control | Objective | Implementation Pattern | Evidence |
|---|---|---|---|
| Encryption at rest/in transit | Protect sensitive data | Managed keys + TLS everywhere | Config snapshots |
| Data retention policy | Reduce risk and cost | Tiered retention with lifecycle rules | Policy and storage config |
| Backup validation | Recover from failures | Periodic restore drills | Restore test reports |

## 5) Monitoring and Detection

| Control | Objective | Implementation Pattern | Evidence |
|---|---|---|---|
| Golden signals dashboards | Operational visibility | Prometheus + Grafana baseline | Dashboard exports |
| Audit logging | Forensics and compliance | Centralized immutable logs | Log system evidence |
| AIOps triage assistant | Faster triage | Risk scoring + summary generation | Incident summaries |

## 6) Governance Notes

- Adapt controls to client regulatory obligations and risk appetite.
- Keep implementation evidence in a central evidence pack.
- Review controls quarterly or after significant incidents.
