# Postmortem: <incident title>

- **Date:**
- **Severity:** low / medium / high
- **Risk score:** (from `scripts/risk_score.sh`)
- **Duration:** detected at — resolved at
- **Owner:**

## What happened

One paragraph, plain language, no jargon. Someone outside the team should
be able to read this and understand what broke.

## Impact

Who/what was affected, and for how long. Be specific: "5xx rate hit 8% for
12 minutes" beats "errors were elevated."

## Timeline

| Time (UTC) | Event |
|---|---|
|  | Alert fired / issue noticed |
|  | Triage started |
|  | Mitigation applied |
|  | Confirmed resolved |

## Root cause

What actually broke, not just what the symptom was.

## What fixed it

The specific mitigation — a rollback, a config change, a restart, a scale-up.

## Follow-up actions

| Action | Owner | Done by |
|---|---|---|
|  |  |  |

## Blameless note

This document exists to fix the system, not to assign blame. If a step in
this timeline reads as "person X should have known Y," rewrite it as "the
system made it possible to not know Y" and fix that instead.
