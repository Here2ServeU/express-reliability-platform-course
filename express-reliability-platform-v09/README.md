# Express Reliability Platform V9 — Cyber-Physical Reliability

## Builds on V8

Before you start V9, copy your personal V8 repository to your local machine and rename it to V9:

```sh
git clone https://github.com/YOUR_USERNAME/express-reliability-platform-v08.git
mv express-reliability-platform-v08 express-reliability-platform-v09
cd express-reliability-platform-v09
```

Use the main class repository for scripts and canonical structure:

- https://github.com/Here2ServeU/express-reliability-platform-course

## 1) Version Purpose

Apply reliability engineering to cyber-physical workflows using telemetry simulation, predictive checks, and automated response loops.

## 2) Chapters Covered

- Chapter 16: Robotics + IoMT Telemetry + Auto-Response (CPS workflows)

## 3) What You Will Build

- Incident simulation workflows across latency, errors, resource stress, and failures.
- AIOps checks plus Slack notifications for operations response.
- DR runbook practice tied to realistic failure scenarios.

## 4) Architecture Diagram (Mermaid)

```mermaid
flowchart LR
	 Sim[Simulation Scripts] --> Telemetry[Operational Telemetry]
	 Telemetry --> AIOps[AIOps Analysis]
	 AIOps --> Alert[Slack Alert]
	 AIOps --> Remedy[Remediation Recommendation]
	 Remedy --> Ops[Operator + Runbook]
```

## 5) Project Structure

```text
express-reliability-platform-v09/
├── aiops/
│   ├── check_slo_sli.py
│   └── predict_and_remediate.py
├── scripts/
│   ├── simulate_latency.py
│   ├── simulate_500_error.py
│   ├── simulate_cpu_memory.py
│   ├── simulate_app_failure.py
│   └── terraform_init_apply.sh
├── slack/
│   └── send_slack_message.py
├── dr/
│   └── runbook.txt
└── README.md
```

## 6) Run Steps

1. Run the local Docker Compose gate first using your latest local stack (from V4):

	```sh
	cd ../express-reliability-platform-v04
	docker compose up --build -d
	curl http://localhost:8080/api/health
	docker compose down
	cd ../express-reliability-platform-v09
	```

2. Promote any infrastructure changes in order: `dev -> staging -> prod`.
3. Install Python 3 and dependencies used by your scripts.
4. Run one failure simulation at a time:

	```sh
	python3 scripts/simulate_latency.py
	python3 scripts/simulate_500_error.py
	python3 scripts/simulate_cpu_memory.py
	python3 scripts/simulate_app_failure.py
	```

5. Run AIOps checks:

	```sh
	python3 aiops/check_slo_sli.py
	python3 aiops/predict_and_remediate.py
	```

6. Send/verify alert path:

	```sh
	python3 slack/send_slack_message.py
	```

7. Execute response steps from `dr/runbook.txt`.

## 7) Validation Checklist

- [ ] All simulation scripts run without syntax/runtime errors.
- [ ] AIOps scripts output prediction/check results.
- [ ] Slack alert path works (or dry-run output is validated).
- [ ] Runbook actions are executed and documented.

## 8) Troubleshooting

- Python package errors: create and activate a virtual environment.
- Slack failures: verify token/channel environment variables.
- No predicted incident: confirm simulation output is being produced before AIOps run.

## 9) Cleanup

- Stop any local processes and remove temporary test data/logs.

## 10) Next Version Preview

In V10, you build on V9 and extend into post-book labs with robotics and quantum-augmented optimization experiments.


