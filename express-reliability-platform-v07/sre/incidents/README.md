# SRE Incident Management — Introduction

A short primer on how incidents get handled once `scripts/risk_score.sh`
(or a human watching Grafana) decides something is wrong.

## Severity levels

| Severity | Meaning | First action |
|---|---|---|
| Low | Degraded but contained | Watch dashboards, no ticket needed yet |
| Medium | Real user impact, contained to one service | Open a ticket, assign an owner |
| High | Real user impact, spreading or unresolved | Declare an incident, page on-call |

These map directly to `scripts/risk_score.sh`'s verdicts.

## Roles during an incident

- **Incident commander** — owns the response, not necessarily the fix. Keeps
  people from working the same problem twice and decides when to escalate.
- **On-call engineer** — first responder, usually the one who gets paged.
- **Communicator** — posts status updates so the IC and responders can stay
  heads-down instead of fielding "is this fixed yet?" questions.

For a platform this size, one person often plays all three roles — the point
of naming them is knowing which hat you're wearing.

## The loop

```
detect → triage → mitigate → resolve → postmortem
```

1. **Detect** — an alert fires (`monitoring/alert.rules.yml`) or a human
   notices.
2. **Triage** — run `scripts/risk_score.sh` (or reason through the same four
   signals by hand) to get a severity.
3. **Mitigate** — stop the bleeding. Doesn't have to be the real fix —
   rolling back a bad deploy counts.
4. **Resolve** — confirm the health endpoint and SLIs are back to baseline,
   sustained, not just one good reading.
5. **Postmortem** — write it up. See `postmortem-template.md`.

## Where this goes next

This is deliberately an introduction, not a full incident-management system.
A fuller version would add: an evidence trail per incident (JSON files, one
per run), automatic Slack paging, and ticket creation (Jira/ServiceNow) —
that's what later versions of this course build out.
