# Chapter 15: Chaos Engineering

## Goal
Practice controlled failure testing so the platform becomes safer and more reliable.

## Safety Rules
- Run one experiment at a time.
- Start with low blast radius.
- Keep a rollback step ready before each test.
- Stop immediately if customer impact is higher than expected.

## Experiment 1: Latency Injection
- Hypothesis: The platform stays within SLO when 300 ms latency is added to one downstream dependency.
- Steady-state metric: API p95 latency remains under 500 ms.
- Local action: Add network delay to one service container.
- Cloud action: Use a safe fault injection on one non-critical target group slice.
- Rollback: Remove the latency rule and confirm recovery.

## Experiment 2: Pod/Task Termination
- Hypothesis: Auto-healing restores healthy capacity in less than 2 minutes.
- Steady-state metric: Availability remains >= 99.9% during test window.
- Local action: Stop one container.
- Cloud action: Stop one task/pod in dev environment.
- Rollback: Let orchestrator reschedule, then verify health checks.

## Experiment 3: CPU Stress
- Hypothesis: Autoscaling and alerts respond before SLO burn exceeds threshold.
- Steady-state metric: Error rate remains below 1%.
- Local action: Apply CPU stress to one API container.
- Cloud action: Run stress test against one dev workload replica.
- Rollback: Stop stress and confirm normal CPU/latency.

## Required Evidence
- Hypothesis and expected result
- Start/end timestamps
- Metrics before/during/after
- Incident notes and mitigation
- Final decision: keep, adjust, or roll back control
