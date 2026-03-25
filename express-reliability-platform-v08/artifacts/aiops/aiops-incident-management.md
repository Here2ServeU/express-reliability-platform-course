# AIOps for Incident Management

## Goal
Use AIOps to detect incidents earlier, summarize impact faster, and guide responders to the right first actions.

## Core AIOps Loop
1. Ingest signals (metrics, logs, events).
2. Detect anomaly.
3. Score incident risk.
4. Generate incident summary.
5. Recommend remediation.
6. Validate recovery against SLO/SLI.

## Incident Signals to Track
- Latency spikes (p95 and p99)
- Error-rate spikes (4xx and 5xx)
- Resource pressure (CPU, memory, restarts)
- Dependency failures (database, queue, cache)

## Risk Score Model (Simple)
- Low: score 0-39
- Medium: score 40-69
- High: score 70-100

Example formula:
- +30 if error rate > 1%
- +30 if p95 latency > SLO threshold
- +20 if restart count increases
- +20 if two or more services fail together

## Incident Summary Template
- Incident ID
- Impacted services
- Severity and risk score
- Suspected root cause
- First recommended action
- Owner and next update time

## Local Test Plan
- Trigger one synthetic latency event.
- Trigger one synthetic error event.
- Verify AIOps summary includes service, impact, cause, action.
- Confirm SLO/SLI values return to baseline after mitigation.

## Cloud Test Plan (dev -> staging -> prod)
- Start in dev with one controlled fault.
- Compare AIOps recommendation with on-call runbook action.
- Promote to staging after stable recovery.
- Use prod only with approval and rollback owner.

## Evidence to Keep
- Raw signals (metrics/log snapshots)
- Risk score output
- Incident summary output
- Action taken and recovery time
- Post-incident review notes
