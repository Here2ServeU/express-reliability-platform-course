# Express Reliability Platform Capstone — Golden Reference Platform

This capstone is the **final integrated platform** that combines all lessons from V1–V10 into one implementation and operating model suitable for regulated healthcare and fintech environments.

Use this folder as your students’ and clients’ **golden platform reference** for:

- Interview preparation
- Client solution architecture
- Reliability and compliance operating model
- Evidence-driven delivery and audits

---

## 1) Capstone Mission

Build and operate one platform that is:

- Reliable by design
- Secure by default
- Observable end-to-end
- Auditable for regulated environments
- Explainable to both technical and non-technical stakeholders

---

## 2) Versions Unified in This Capstone

| Capability | Source Version(s) | Capstone Outcome |
|---|---|---|
| Local app foundations | V1 | Fast local bootstrap + developer workflow |
| Containerization + service layout | V2 | Portable multi-service baseline |
| Compose + IAM/OIDC + ECS/ALB | V3 | Cloud identity and deployment pipeline |
| Monitoring + simulation | V4 | Proactive observability and stress testing |
| EKS + self-healing | V5 | Kubernetes reliability controls |
| Terraform discipline | V6 | Repeatable infrastructure lifecycle |
| Runbooks + incident ops | V7 | Operational excellence model |
| AIOps | V8 | Risk scoring and faster triage |
| Cyber-physical reliability | V9 | Telemetry-driven auto-response workflows |
| Quantum/robotics extensions | V10 | Advanced optimization lab capabilities |

---

## 3) Golden Architecture (High Level)

```mermaid
flowchart LR
    U[Users / Partners] --> WAF[WAF + Edge Protection]
    WAF --> ALB[ALB / Ingress]
    ALB --> UI[Web UI Service]
    UI --> NODE[Node API]
    UI --> FLASK[Flask API]

    NODE --> DATA[(Transactional Data Store)]
    FLASK --> DATA

    NODE --> OBS[Telemetry Pipeline]
    FLASK --> OBS
    UI --> OBS

    OBS --> PROM[Prometheus]
    OBS --> GRAF[Grafana]
    OBS --> ALERT[Alerting + Slack]

    ALERT --> RUNBOOK[Runbooks + Incident Workflow]
    RUNBOOK --> REMED[Automated / Guided Remediation]

    IAC[Terraform Modules] --> CLOUD[AWS Account(s)]
    CI[GitHub Actions + OIDC] --> CLOUD
    CLOUD --> EKS[EKS Runtime]
    CLOUD --> ECS[ECS Runtime]
```

---

## 4) Regulated Environment Best Practices Included

### Security and Identity
- Least-privilege IAM roles and scoped service accounts
- OIDC-based CI/CD federation (no long-lived static credentials)
- Secrets managed outside source code
- Network segmentation and environment isolation (`shared`, `live`)

### Reliability Engineering
- Defined SLO/SLI catalog with error budgets
- Health probes, autoscaling policies, and graceful degradation
- Incident severity model with runbook-driven response
- Disaster recovery exercises with documented recovery objectives

### Compliance and Audit Readiness
- Traceable change management through Git + PR workflows
- Control evidence pack (who changed what, when, and why)
- Standardized incident documentation and post-incident review
- Data handling boundaries for healthcare and fintech workloads

### Observability and AIOps
- Golden signals: latency, traffic, errors, saturation
- Alert thresholds aligned to SLO commitments
- Risk scoring and incident summarization for fast triage
- Simulation-driven validation before production promotion

---

## 5) Program Delivery Model (How Students and Clients Use It)

1. Build capability in sequence from V1 → V10.
2. Use this capstone to consolidate into one final operating platform.
3. Complete all templates under `artifacts/`.
4. Use `docs/interview-and-client-playbook.md` to present architecture and outcomes.
5. Use `docs/controls-matrix.md` during client onboarding and audits.

---

## 6) Capstone Exit Criteria (Golden Standard)

A student/client implementation is considered complete when all are true:

- [ ] Architecture diagram matches deployed reality.
- [ ] SLO/SLI definitions exist per critical service.
- [ ] Alerting, runbooks, and escalation path are tested.
- [ ] IaC workflow is reproducible across environments.
- [ ] Security controls and evidence artifacts are documented.
- [ ] At least one reliability simulation and one DR drill are completed.
- [ ] Interview/client walkthrough can be delivered in 15 minutes.

---

## 7) Folder Structure

```text
express-reliability-platform-capstone/
├── README.md
├── docs/
│   ├── reference-architecture.md
│   ├── controls-matrix.md
│   ├── implementation-roadmap.md
│   └── interview-and-client-playbook.md
└── artifacts/
    ├── compliance/
    │   └── evidence-pack-checklist.md
    ├── runbooks/
    │   └── incident-runbook-template.md
    └── sre/
        └── slo-sli-catalog-template.md
```

---

## 8) Next Step

Start with `docs/implementation-roadmap.md` and execute Phase 1 through Phase 6 in order.

---

## 9) Web UI Guide — `apps/web-ui/index.html`

### Platform Continuity

The capstone UI keeps the same V2 regulated readiness console and completes it as the final student-owned platform. It should feel like the same platform students have matured from V2 through V10, now ready for a portfolio, interview, or client walkthrough.

### What the Capstone UI Does

The capstone `index.html` is the final regulated platform readiness console. It combines the learning path from V2 through V10 into one portfolio-ready interface that a student can present to interviewers, clients, banks, hospitals, and other high-trust organizations.

The page checks:

- Reliability: SLOs, SLIs, runbooks, chaos drills, and recovery validation.
- Cost efficiency: FinOps tagging, ownership, and governance.
- Security and compliance: mapped controls, audit evidence, and regulated operating practices.
- Intelligence: AIOps, MLOps readiness, predictive remediation, and operational automation.

It also includes a **creator name** field. When a student enters their name and generates the scorecard, the page saves that creator name in browser `localStorage` and displays:

```text
Final project created by <student name>, T2S regulated platform engineer.
```

### What It Is Used For

Use the capstone UI as the final presentation surface for the entire program. The goal is for each student to show that they can build and explain a complete regulated reliability platform, not just individual scripts or infrastructure pieces.

This UI is useful for:

- Final student demos.
- Interview portfolio walkthroughs.
- Client architecture conversations.
- Capstone grading and review.
- Showing how the platform compares conceptually to mature observability, FinOps, ITSM, and AIOps tools.

### How to Read the Results

The capstone UI generates a final JSON scorecard.

| Field | Meaning |
|---|---|
| `version` | Confirms this is the capstone assessment. |
| `creator` | Student or engineer presenting the platform. |
| `platform` | Final project or platform name. |
| `target_industry` | Intended industry focus: fintech, healthcare, or both. |
| `readiness_score` | Overall capstone score from 0 to 100. |
| `readiness_band` | Final interpretation: `golden reference`, `portfolio ready`, `needs final polish`, or `not capstone ready`. |
| `domains.reliability` | Measures operational resilience and recovery readiness. |
| `domains.cost_efficiency` | Measures FinOps and governance maturity. |
| `domains.security_compliance` | Measures controls, audit evidence, and regulated readiness. |
| `domains.intelligence_aiops_mlops` | Measures AIOps, MLOps, and remediation maturity. |
| `portfolio_message` | A plain-language statement students can use in their final presentation. |

Suggested interpretation:

- `90-100`: Golden reference. Strong final portfolio story.
- `80-89`: Portfolio ready. Good for demos, with minor polish.
- `70-79`: Needs final polish. Review missing evidence or controls.
- `<70`: Not capstone ready. Strengthen reliability, evidence, controls, or automation.

### How Students Customize It

1. Open the capstone UI in a browser.
2. Enter the student's name in **Creator name**.
3. Enter a final platform name.
4. Select the target industry and maturity options.
5. Click **Generate Capstone Scorecard**.
6. Use the displayed creator credit and JSON scorecard in the final presentation.

The creator name is saved only in the current browser through `localStorage`; it is not sent to a server.
