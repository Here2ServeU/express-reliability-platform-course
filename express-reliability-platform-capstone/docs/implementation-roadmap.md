# Implementation Roadmap — Capstone Build Plan

This roadmap helps teams deliver the capstone in phased increments.

## Phase 1 — Foundation and Identity

- Finalize repo governance and branch protections
- Set up environment strategy (`shared`, `live`)
- Configure IAM roles and OIDC federation
- Define naming conventions and tagging policy

Exit criteria:

- Secure CI/CD authentication works end-to-end
- Baseline security controls are documented

## Phase 2 — Runtime and Deployment

- Stand up service workloads (Node API, Flask API, Web UI)
- Establish ECS/EKS deployment pattern
- Add ingress/load balancing and health checks

Exit criteria:

- All services reachable with health checks passing
- Rollback path tested

## Phase 3 — Observability and SRE Baseline

- Deploy Prometheus and Grafana
- Define and publish SLO/SLI catalog
- Create alert routing and severity policy

Exit criteria:

- Dashboards operational
- Alerting aligned to SLO thresholds

## Phase 4 — Incident and DR Operations

- Build runbook catalog for top risks
- Execute incident simulations
- Practice one disaster recovery drill

Exit criteria:

- Incident response timing documented
- DR drill report completed

## Phase 5 — AIOps and Automation

- Add risk scoring pipeline
- Add incident summary generation
- Integrate recommendation loop into operations

Exit criteria:

- AI-assisted triage produces actionable summaries
- Operators validate recommendation quality

## Phase 6 — Capstone Certification Pack

- Complete controls matrix
- Complete evidence-pack checklist
- Complete interview/client presentation narrative

Exit criteria:

- Golden platform package ready for interview and client walkthrough

## Suggested Delivery Timeline

- Intensive bootcamp: 2–4 weeks
- Part-time cohort: 6–10 weeks
- Client pilot: 8–12 weeks depending on environment complexity
