# Express Reliability Platform V7 — Enterprise Reliability Operations

## Builds on V6

Before you start V7, copy your personal V6 repository to your local machine and rename it to V7:

```sh
git clone https://github.com/YOUR_USERNAME/express-reliability-platform-v06.git
mv express-reliability-platform-v06 express-reliability-platform-v07
cd express-reliability-platform-v07
```

Use the main class repository for scripts and canonical structure:

- https://github.com/Here2ServeU/express-reliability-platform-course

## 1) Version Purpose

Translate infrastructure maturity into operational maturity: runbooks, incident response, SLO/SLI thinking, disaster recovery basics, and chaos engineering.

## 2) Chapters Covered

- Chapter 14: Runbooks + Incident Response (SLOs/SLIs, on-call mindset, DR basics)
- Chapter 15: Chaos Engineering (controlled failure testing, resilience validation, and recovery confidence)

## Training Workflow (Understand -> Build -> Test -> Break -> Fix -> Explain -> Automate -> Improve)

1. Understand: Review incident lifecycle, SLO/SLI, DR, and chaos safety rules.
2. Build: Prepare runbooks, on-call, and DR artifacts.
3. Test: Execute incident and chaos drills in controlled scope.
4. Break: Introduce one safe fault at a time.
5. Fix: Restore service using runbooks, logs, metrics, and alerts.
6. Explain: Document what failed, why it failed, and what fixed it.
7. Automate: Improve drill scripts, alerts, and runbook actions.
8. Improve: Reduce recovery time and strengthen reliability guardrails.

## 3) What You Will Build

- A practical incident response workflow tied to your platform environments.
- Operational checklists that guide detection, triage, mitigation, and recovery.
- A chaos engineering playbook to run safe experiments locally and in cloud environments.

## 4) Architecture Diagram (Mermaid)

```mermaid
flowchart LR
    Alert[Alert Signal] --> Triage[Incident Triage]
    Triage --> Runbook[Runbook Steps]
    Runbook --> Mitigation[Mitigation Action]
    Mitigation --> Verify[Verify SLI Recovery]
    Verify --> Postmortem[Post-Incident Review]
```

## 5) Project Structure

```text
express-reliability-platform-v07/
├── artifacts/
│   ├── chaos/
│   │   └── chaos-engineering.md
│   ├── compliance/
│   │   └── dr-basics.md
│   ├── runbooks/
│   │   └── incident-sev1-api-latency.md
│   └── sre/
│       ├── oncall-rotation.md
│       └── slo-sli-catalog.md
├── environments/
│   ├── live/
│   └── shared/
├── infrastructure/
│   └── bootstrap/
├── modules/
│   ├── alb/
│   ├── eks/
│   ├── iam/
│   └── vpc/
├── scripts/
│   ├── chaos_cloud_test.sh
│   ├── chaos_local_test.sh
│   └── terraform_init_apply.sh
└── README.md
```

## 6) Run Steps

1. Run the local Docker Compose gate first using your latest local stack (from V4):

    ```sh
    cd ../express-reliability-platform-v04
    docker compose up --build -d
    curl http://localhost:8080/api/health
    docker compose down
    cd ../express-reliability-platform-v07
    ```

2. Deploy platform baseline with Terraform helper script.
3. Promote any infrastructure changes in order: `dev -> staging -> prod`.
4. Define and review SLI targets in `artifacts/sre/slo-sli-catalog.md`.
5. Define on-call escalation in `artifacts/sre/oncall-rotation.md`.
6. Review DR basics in `artifacts/compliance/dr-basics.md`.
7. Practice one incident drill end-to-end using `artifacts/runbooks/incident-sev1-api-latency.md`:
   - detect
   - classify
   - mitigate
   - recover
   - document

## 7) Chapter 15: Chaos Engineering

Use `artifacts/chaos/chaos-engineering.md` as your guide.

### 7.1 Local Chaos Test (Docker Compose)

1. Start your local platform stack.
2. Run a controlled local chaos test:

    ```sh
    chmod +x scripts/chaos_local_test.sh
    ./scripts/chaos_local_test.sh node-api 30
    ```

3. Validate expected behavior:
    - Health endpoint still responds: `http://localhost:8080/api/health`
    - Alerts and logs show the injected stress period.
    - Recovery time matches your SLO targets.

### 7.2 Cloud Chaos Test (dev -> staging -> prod)

1. Start in `dev` only.
2. Run the cloud chaos checklist helper:

    ```sh
    chmod +x scripts/chaos_cloud_test.sh
    ./scripts/chaos_cloud_test.sh dev
    ```

3. Capture evidence: latency, error rate, and recovery time.
4. If stable in `dev`, repeat in `staging`.
5. Run in `prod` only with approval and rollback owner assigned.

### 7.3 Chaos Experiment Safety Rules

- Run one experiment at a time.
- Keep blast radius small.
- Keep rollback steps ready before test start.
- Stop test immediately if impact exceeds guardrails.

## 8) Validation Checklist

- [ ] SLO/SLI targets are documented and measurable.
- [ ] On-call rotation and escalation timeline are documented.
- [ ] At least one runbook exists for a high-impact incident.
- [ ] DR basics are documented with RTO and RPO targets.
- [ ] Drill execution time and communication timeline are captured.
- [ ] Recovery is validated against objective metrics.
- [ ] At least one local chaos experiment is executed and documented.
- [ ] At least one cloud chaos experiment is executed in `dev` and reviewed.

## 9) Troubleshooting

- Alert fatigue: tighten thresholds and prioritize critical alerts first.
- Slow incident response: simplify runbook steps and assign clear ownership.
- Noisy metrics: standardize labels and time windows for SLI measurement.
- Chaos test too risky: reduce scope to one service and shorten test duration.
- Recovery too slow after chaos test: verify autoscaling and health-check settings.

## 10) Cleanup

- Remove temporary test resources and close all drill tickets/issues.
- Archive chaos experiment evidence with timestamps and metrics snapshots.

## 11) Next Version Preview

In V8, you build on V7 and introduce AIOps patterns for risk scoring, pattern detection, and faster incident summaries.


