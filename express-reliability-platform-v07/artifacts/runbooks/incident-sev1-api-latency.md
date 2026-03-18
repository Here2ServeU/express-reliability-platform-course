# Incident Runbook: SEV1 API Latency

## Goal
Restore API latency to normal in less than 30 minutes.

## Trigger
Use this runbook when p95 latency is above target for 10 minutes.

## SLO/SLI Link
- SLO: p95 latency < 500 ms for customer API requests.
- SLI source: API gateway or service latency metrics.

## Roles
- Incident Commander: leads the response.
- Communications Lead: posts updates every 15 minutes.
- Operations Engineer: applies mitigations.

## Steps
1. Confirm alert is real by checking p95 latency and error rate dashboards.
2. Check recent deploys and roll back if latency started right after deploy.
3. Scale up affected service replicas.
4. Check dependency health (database, cache, message queue).
5. Apply temporary traffic controls (rate limit or shed non-critical traffic).
6. Verify p95 latency returns below threshold for 15 minutes.
7. Close incident and create post-incident notes.

## Communications Template
- Status: Investigating elevated API latency.
- Impact: Some requests are slower than normal.
- Next update: 15 minutes.

## Exit Criteria
- p95 latency is below target.
- Error rate is stable.
- Incident notes are documented.
