
# Express Reliability Platform V9

## 1) Version Purpose

Version 10 focuses on a compact hospital operations simulation that connects robotics, telemetry, AIOps, and remediation workflows.

## 2) Project Structure

```text
express-reliability-platform-v09/
├── aiops/
│   ├── check_slo_sli.py
│   └── predict_and_remediate.py
├── robotics/
│   └── robot_simulation.py
├── telemetry/
│   └── hospital_telemetry.py
├── remediation/
│   └── fix_robot_issue.py
├── scripts/
│   ├── simulate_latency.py
│   ├── simulate_error.py
│   └── terraform_init_apply.sh
├── artifacts/
│   └── evidence/
├── environments/
├── modules/
├── infrastructure/
├── .gitignore
└── README.md
```

## 3) What This Version Demonstrates

- Robot task simulation in a hospital environment.
- Basic telemetry generation for latency, battery, and error conditions.
- SLO and SLI checks for service health review.
- Simple remediation guidance for common robot incidents.

## 4) Run Steps

Run these commands from the V9 folder:

```sh
python3 robotics/robot_simulation.py
python3 telemetry/hospital_telemetry.py
python3 scripts/simulate_latency.py
python3 scripts/simulate_error.py
python3 aiops/check_slo_sli.py
python3 aiops/predict_and_remediate.py
python3 remediation/fix_robot_issue.py
```

If you need Terraform initialization and apply:

```sh
./scripts/terraform_init_apply.sh infrastructure
```

## 5) Validation Checklist

- [ ] Robotics simulation runs without import or path errors.
- [ ] Telemetry script prints hospital system metrics.
- [ ] Latency and error simulation scripts execute.
- [ ] AIOps scripts accept input and return expected guidance.
- [ ] Remediation script provides a recovery path for a robot issue.

## 6) Notes

- Store screenshots, logs, and demo output under `artifacts/evidence/`.
- Keep infrastructure-specific code under `infrastructure/`, reusable units under `modules/`, and environment-specific state under `environments/`.

---

## 7) Web UI Guide: `apps/web-ui/index.html`

### Platform Continuity

The V9 UI keeps the same V2 regulated readiness console and evolves it with healthcare telemetry, robotics/IoMT status, and predictive remediation checks. Students should experience this as the same platform growing, not as a separate app.

### What the V9 UI Does

The V9 `index.html` is the healthcare reliability intelligence console. It extends the platform into hospital operations by evaluating telemetry, robot or IoMT status, and remediation maturity.

The page checks:

- Reliability through hospital telemetry, SLO checks, and clinical workflow health.
- Cost efficiency through efficient response automation.
- Security and compliance through healthcare audit boundaries.
- Intelligence maturity through predictive remediation and safe recommended actions.

### What It Is Used For

Use the V9 UI to show how the platform can support advanced healthcare scenarios. Students can demonstrate how telemetry from hospital systems or robotic workflows can become operational evidence and remediation guidance.

This UI is useful for:

- Explaining cyber-physical reliability in hospital environments.
- Connecting telemetry signals to safe operational decisions.
- Practicing incident response for clinical workflow risk.
- Preparing the final story for the capstone platform.

### How to Read the Results

The UI generates a healthcare telemetry readiness scorecard.

| Field | Meaning |
|---|---|
| `workflow` | The hospital or robot workflow being assessed. |
| `readiness_score` | Overall healthcare platform readiness. |
| `readiness_band` | Plain-language score interpretation. |
| `recommended_action` | Suggested first action based on telemetry or robot state. |
| `domains.reliability` | Drops when telemetry is critical or robot status is unhealthy. |
| `domains.cost_efficiency` | Improves when remediation is guided or predictive. |
| `domains.security_compliance` | Reflects healthcare audit readiness. |
| `domains.intelligence_aiops_mlops` | Shows maturity of predictive remediation. |

If robot status is `Fault detected` or telemetry is `Critical`, the recommended action should be treated as an incident-response prompt, not a final clinical decision.
