

# Express Reliability Platform V9

## Step-by-Step Guide: Provisioning the Infrastructure

### 1. Install Prerequisites
- [Git](https://git-scm.com/downloads)
- [Python](https://www.python.org/downloads/)
- [Node.js](https://nodejs.org/en/download/)
- [Slack account & API token](https://api.slack.com/)

### 2. Clone the Repository
```sh
git clone <URL-of-this-repo>
cd express-reliability-platform-course/express-reliability-platform-v9
```

### 3. Provision Infrastructure (Cloud or Local)
- For cloud: Use Terraform or your preferred IaC tool to provision cloud resources (EKS, EC2, etc.) if needed for full-scale deployment. In this project, we use EKS. Use the previous versions to review how to do it. 
- For local testing: You can run all scripts and AIOps logic directly on your laptop. No cloud resources required for simulation and basic testing.

### 4. Simulate Application Issues
Run scripts in the `scripts/` folder to simulate:
- Latency: `python scripts/simulate_latency.py`
- 500 Error: `python scripts/simulate_500_error.py`
- CPU/Memory: `python scripts/simulate_cpu_memory.py`
- App Failure: `python scripts/simulate_app_failure.py`

### 5. Run AIOps Prediction & Remediation
Use scripts in the `aiops/` folder:
- Prediction & Remediation: `python aiops/predict_and_remediate.py`
- SLO/SLI Check: `python aiops/check_slo_sli.py`

### 6. Integrate Slack for Alerts
Run the Slack integration script:
- `python slack/send_slack_message.py`
Configure your Slack API token as needed for real integration.

### 7. Review Runbooks & Practice DR
Read and follow guides in the `dr/` folder:
- `dr/runbook.txt` for incident management and DR drills.

---

## How to Test Locally
You can test all features on your laptop:
1. Make sure Python and Node.js are installed.
2. Open a terminal and run the simulation scripts in the `scripts/` folder.
3. Run the AIOps scripts in the `aiops/` folder to see predictions and remediation steps.
4. Run the Slack script in the `slack/` folder to simulate alert messages.
5. Read and follow the runbook in the `dr/` folder for incident management practice.

---

## Chapters Covered
- Chapter 35: Simulating Errors and Latency
- Chapter 36: AIOps for Prediction and Automated Remediation
- Chapter 37: Slack Integration for Proactive Alerts
- Chapter 38: SLOs, SLIs, and AIOps Monitoring
- Chapter 39: Disaster Recovery, Runbooks, and Incident Management

---

## Overview
Version 9 introduces AIOps-driven prediction, automated remediation, and proactive incident management. The platform simulates real-world failures, leverages AI models (LSTM, TCN) for forecasting, integrates Slack for alerting, and provides runbooks for disaster recovery and incident response.

### Key Features
- **Error & Latency Simulation**: Scripts to simulate latency, 500 errors, CPU/memory exhaustion, and app failures.
- **AIOps Prediction & Remediation**: AI models predict incidents and generate remediation steps.
- **Slack Integration**: Engineers receive real-time alerts and recommendations via Slack.
- **SLO/SLI Monitoring**: Automated checks and reporting on service reliability.
- **Disaster Recovery & Runbooks**: Step-by-step guides and drills for incident management and communications.

---

## Troubleshooting Tips
- If a script fails, check that Python/Node.js is installed and your environment variables are set.
- For Slack integration, ensure your API token is correct and your workspace allows bot messages.
- If AIOps scripts do not detect issues, verify that simulation scripts are running and producing expected outputs.

---

## Example Directory Structure
- `scripts/`: Error and latency simulation scripts
- `aiops/`: Prediction, remediation, and SLO/SLI scripts
- `slack/`: Slack integration scripts
- `dr/`: Runbooks and disaster recovery guides

---

## Next Steps
- Expand AIOps models and automation
- Integrate with additional messaging platforms
- Enhance DR and incident management workflows

---


