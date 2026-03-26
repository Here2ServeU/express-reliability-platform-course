
# Express Reliability Platform V10

Version 10 focuses on a compact hospital operations simulation that connects robotics, telemetry, AIOps, and remediation workflows.

## Project Structure

```text
express-reliability-platform-v10/
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

## What This Version Demonstrates

- Robot task simulation in a hospital environment.
- Basic telemetry generation for latency, battery, and error conditions.
- SLO and SLI checks for service health review.
- Simple remediation guidance for common robot incidents.

## Run Steps

Run these commands from the V10 folder:

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

## Validation Checklist

- [ ] Robotics simulation runs without import or path errors.
- [ ] Telemetry script prints hospital system metrics.
- [ ] Latency and error simulation scripts execute.
- [ ] AIOps scripts accept input and return expected guidance.
- [ ] Remediation script provides a recovery path for a robot issue.

## Notes

- Store screenshots, logs, and demo output under `artifacts/evidence/`.
- Keep infrastructure-specific code under `infrastructure/`, reusable units under `modules/`, and environment-specific state under `environments/`.
