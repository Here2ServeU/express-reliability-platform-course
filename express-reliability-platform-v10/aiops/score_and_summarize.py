#!/usr/bin/env python3
"""
Intelligence layer — risk scoring + incident summary (the AIOps core).

Turns a detected signal into a machine-readable incident evidence file that the
rest of the platform consumes:

  - a risk score (0-100) and a severity band (high / medium / low)
  - a plain-language summary an on-call engineer can read in seconds
  - a recommended action
  - the EXACT resolve command the engineer runs to fix it
  - an owner and a UTC timestamp

The evidence JSON is written to artifacts/evidence/<incident_id>.json and is the
same shape the Slack alerter (alerting/send_slack_alert.py) reads.

Usage:
  python3 aiops/score_and_summarize.py --signal latency --service node-api
  python3 aiops/score_and_summarize.py --signal error_rate --service flask-api --value 0.09
  python3 aiops/score_and_summarize.py --signal cpu --service node-api --incident-id INC-1001
"""

import os
import json
import argparse
from datetime import datetime, timezone

# Per-signal scoring profile: base risk weight, default measured value (used when
# the caller does not pass --value), the human action, and the resolve verb that
# remediation/resolve_incident.sh understands.
SIGNALS = {
    "latency": {
        "weight": 70,
        "default_value": 1200,
        "label": "elevated p95 latency",
        "action": "Restart the affected service and shed load; check upstream dependency latency.",
        "resolve": "latency",
    },
    "error_rate": {
        "weight": 85,
        "default_value": 0.08,
        "label": "elevated 5xx error rate",
        "action": "Roll back the most recent deploy and inspect application logs.",
        "resolve": "error_rate",
    },
    "cpu": {
        "weight": 75,
        "default_value": 0.92,
        "label": "CPU/memory saturation",
        "action": "Scale the service horizontally and clear cached state.",
        "resolve": "cpu",
    },
    "pod_kill": {
        "weight": 90,
        "default_value": 1,
        "label": "pod crash / service unavailable",
        "action": "Restart the workload and verify the readiness probe recovers.",
        "resolve": "pod_kill",
    },
}


def severity_for(score: int) -> str:
    if score >= 80:
        return "high"
    if score >= 50:
        return "medium"
    return "low"


def score_signal(signal: str, value: float) -> int:
    """Combine the signal's base weight with how far the value exceeds its norm."""
    profile = SIGNALS[signal]
    base = profile["weight"]
    norm = profile["default_value"] or 1
    overshoot = max(0.0, (value - norm) / norm)        # 0 when at/below norm
    score = base + min(15, overshoot * 30)             # cap the overshoot bonus
    return int(max(0, min(100, round(score))))


def build_evidence(signal: str, service: str, value: float, incident_id: str) -> dict:
    profile = SIGNALS[signal]
    score = score_signal(signal, value)
    severity = severity_for(score)
    resolve_command = f"./remediation/resolve_incident.sh {profile['resolve']} {service}"

    summary = (
        f"AIOps detected {profile['label']} on {service} "
        f"(measured {value}). Risk scored {score}/100 -> {severity.upper()}. "
        f"Recommended: {profile['action']}"
    )

    return {
        "incident_id": incident_id,
        "service": service,
        "signal": signal,
        "measured_value": value,
        "risk_score": score,
        "severity": severity,
        "recommended_action": profile["action"],
        "resolve_command": resolve_command,
        "summary": summary,
        "owner": os.environ.get("ONCALL_OWNER", "platform-oncall"),
        "generated_at_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Score and summarize an incident (AIOps)")
    parser.add_argument("--signal", required=True, choices=list(SIGNALS))
    parser.add_argument("--service", default="node-api", help="Affected service name")
    parser.add_argument("--value", type=float, help="Measured value (defaults per signal)")
    parser.add_argument("--incident-id", help="Incident ID (default INC-<signal>)")
    parser.add_argument(
        "--out-dir",
        default="artifacts/evidence",
        help="Directory to write the evidence JSON",
    )
    args = parser.parse_args()

    value = args.value if args.value is not None else SIGNALS[args.signal]["default_value"]
    incident_id = args.incident_id or f"INC-{args.signal.upper()}"

    evidence = build_evidence(args.signal, args.service, value, incident_id)

    os.makedirs(args.out_dir, exist_ok=True)
    out_path = os.path.join(args.out_dir, f"{incident_id}.json")
    with open(out_path, "w") as f:
        json.dump(evidence, f, indent=2)

    print(json.dumps(evidence, indent=2))
    print(f"\nEvidence written to {out_path}")
    print(f"Next: python3 alerting/send_slack_alert.py --evidence-file {out_path}")


if __name__ == "__main__":
    main()
