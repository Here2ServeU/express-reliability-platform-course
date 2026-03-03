# Reference Architecture — Regulated Healthcare + Fintech Platform

This document defines the target architecture pattern for the capstone.

## 1) Design Principles

- Security by default
- Reliability by design
- Compliance as a continuous activity
- Automation first, manual as fallback
- Evidence generation built into delivery workflow

## 2) Environment Strategy

- `shared`: foundational services (networking, base IAM, shared observability)
- `live`: production-like workload environment
- Optional `sandbox`: experimentation and training

Promotion path:

1. Sandbox validation
2. Shared/live plan checks
3. Controlled release to live with rollback strategy

## 3) Workload Pattern

Core services:

- Web UI
- Node API
- Flask API

Runtime pattern:

- ECS for transitional workloads and compatibility
- EKS for long-term self-healing, autoscaling, and policy-driven operations

## 4) Data and Security Boundaries

- Separate data classification zones for regulated and non-regulated data
- Encrypt data in transit and at rest
- Restrict privileged access with role-based controls and approval flow
- Keep sensitive data out of logs and alert payloads

## 5) Observability Baseline

Minimum telemetry per service:

- Request count
- Error count and rate
- p50/p95/p99 latency
- CPU/memory saturation
- Dependency health status

## 6) Reliability Targets (Example)

- Availability SLO: 99.9%
- Error-rate SLO: < 1% over rolling 30-day window
- p95 latency SLO: < 300 ms for key APIs

Teams should tailor targets to client context and business criticality.

## 7) Incident Operations Pattern

- Detect via alerts tied to SLI thresholds
- Triage via severity model (SEV1–SEV4)
- Mitigate with runbook-first approach
- Communicate status at fixed intervals
- Complete post-incident review with corrective actions

## 8) Compliance Alignment (Non-Exhaustive)

Healthcare-oriented controls:

- Access logging
- Data minimization
- Backup and recovery testing
- Incident documentation and traceability

Fintech-oriented controls:

- Strong identity and authorization controls
- Segregation of duties
- Change traceability and approval
- Continuous monitoring for anomalous events

Use client legal/compliance teams to map this architecture to required standards and control frameworks.
