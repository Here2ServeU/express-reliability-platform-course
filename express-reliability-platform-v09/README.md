# Express Reliability Platform V9: The Complete Incident Pipeline

## Version Purpose

Version 9 aligns with the Word guide's incident pipeline. It builds on V8 governance and adds Slack
alerts, ServiceNow incidents, Jira issues, chaos drills, and an automated postmortem script.

## Goal

Configure Alertmanager to send Slack messages when alerts fire. Create ServiceNow and Jira tickets
automatically through REST APIs. Run four chaos engineering drills and post a structured postmortem.

## Project Structure

```text
express-reliability-platform-v09/
├── apps/                         # same application services carried from V8
├── environments/                 # shared and live Terraform layers
├── governance/                   # V8 Gatekeeper policies
├── infrastructure/               # bootstrap state resources
├── modules/                      # reusable Terraform modules
├── incident/
│   ├── slack_alert.sh
│   ├── servicenow_ticket.sh
│   ├── jira_issue.sh
│   ├── postmortem.sh
│   ├── send_slack_message.py
│   ├── create_servicenow_ticket.py
│   └── create_jira_issue.py
├── chaos/
│   └── run_chaos_drill.sh
├── artifacts/evidence/
└── scripts/
    ├── cleanup_v9.sh
    ├── simulate_latency.py
    ├── simulate_error.py
    └── terraform_init_apply.sh
```

## Prerequisites

Before running this version, confirm:

- [ ] **Terraform ≥ 1.5, kubectl ≥ 1.29, helm ≥ 3.14, and AWS CLI v2** installed.
- [ ] **Docker Desktop is running** — verify: `docker ps`.
- [ ] **AWS CLI v2 configured** with credentials for EKS, IAM, EC2, and ECR — verify: `aws sts get-caller-identity`.
- [ ] **Make the helper scripts executable** (one time):
  ```sh
  chmod +x scripts/*.sh
  ```

## Run Steps

Dry-run the Slack, ServiceNow, and Jira scripts without credentials:

```sh
./incident/slack_alert.sh INFO "Pipeline test" "Slack dry-run message"
./incident/servicenow_ticket.sh "Pipeline test incident" "2"
./incident/jira_issue.sh "Pipeline test issue" "Dry-run Jira issue"
```

Run a chaos drill:

```sh
./chaos/run_chaos_drill.sh INC-CHAOS-001 node-api latency
```

Generate a postmortem:

```sh
INCIDENT_ID=INC-CHAOS-001 SERVICE=node-api IMPACT="Latency spike" ROOT_CAUSE="Chaos drill" RECOVERY_TIME="45s" ./incident/postmortem.sh
```

## Validation Checklist

- [ ] Alertmanager configuration routes alerts to Slack.
- [ ] A test alert reaches Slack.
- [ ] ServiceNow ticket creation works or dry-run payload is valid.
- [ ] Jira issue creation works or dry-run payload is valid.
- [ ] Four chaos drills run and record results.
- [ ] The postmortem script prints and posts a structured summary.
