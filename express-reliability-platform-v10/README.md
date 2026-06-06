# Express Reliability Platform V10: Full Automation and Recovery

## Version Purpose

Version 10 is the self-healing automation version from the Word guide. It builds on V9's incident
pipeline and adds recovery scripts, a recovery policy loop, a chaos suite, and capstone README notes.

## Goal

Build three automated recovery scripts for common failure modes. Bundle all four chaos drills into one
chaos suite. Capture recovery evidence and prepare the final portfolio README.

## Project Structure

```text
express-reliability-platform-v10/
├── apps/                         # same application services carried from V9
├── governance/                   # V8 policies
├── incident/                     # V9 Slack, ServiceNow, Jira, postmortem
├── chaos/                        # V9 chaos drills
├── automation/
│   ├── fix_crashloop.sh
│   ├── fix_memory_pressure.sh
│   ├── fix_unreachable.sh
│   └── recovery_policy.sh
├── scripts/
│   ├── chaos_suite.sh
│   ├── cleanup_v10.sh
│   ├── run_intelligence_loop.sh
│   ├── simulate_latency.py
│   ├── simulate_500_error.py
│   └── simulate_cpu_memory.py
└── docs/
    └── README.md
```

## Run Steps

Run individual recovery scripts:

```sh
./automation/fix_crashloop.sh
DEPLOYMENT=node-api ./automation/fix_memory_pressure.sh
SERVICE_URL=http://localhost:8080/health DEPLOYMENT=web-ui ./automation/fix_unreachable.sh
```

Run the recovery policy loop:

```sh
INTERVAL_SECONDS=30 ./automation/recovery_policy.sh
```

Run the chaos suite:

```sh
./scripts/chaos_suite.sh
```

## Validation Checklist

- [ ] CrashLoopBackOff recovery restarts the affected deployment.
- [ ] Memory pressure recovery scales a deployment by one replica.
- [ ] Unreachable-service recovery restarts the target deployment.
- [ ] The recovery policy loop runs all three fixers.
- [ ] The chaos suite runs all four V9 drills.
- [ ] Evidence is captured under `artifacts/evidence/`.
