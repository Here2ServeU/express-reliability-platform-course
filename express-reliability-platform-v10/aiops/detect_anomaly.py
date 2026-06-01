#!/usr/bin/env python3
"""
Intelligence layer: anomaly detection.

Compares a measured signal against its SLO threshold and decides whether the
behavior is anomalous. This is the first stage of the AIOps loop:

    detect -> score/summarize -> alert -> resolve

Usage:
  python3 aiops/detect_anomaly.py --signal latency --value 1200
  python3 aiops/detect_anomaly.py --signal error_rate --value 0.08
  python3 aiops/detect_anomaly.py --signal cpu --value 0.92
  python3 aiops/detect_anomaly.py --signal pod_kill --value 1

Each signal has a threshold drawn from the platform SLOs. If the measured value
crosses the threshold, the signal is flagged as an anomaly.
"""

import argparse
import json

# SLO-derived thresholds. "higher_is_worse" tells the detector which direction
# of the threshold counts as a breach.
THRESHOLDS = {
    "latency":    {"threshold": 500,  "unit": "ms",      "higher_is_worse": True},
    "error_rate": {"threshold": 0.05, "unit": "ratio",   "higher_is_worse": True},
    "cpu":        {"threshold": 0.85, "unit": "ratio",   "higher_is_worse": True},
    "pod_kill":   {"threshold": 1,    "unit": "restarts", "higher_is_worse": True},
}


def detect(signal: str, value: float) -> dict:
    if signal not in THRESHOLDS:
        raise ValueError(f"Unknown signal '{signal}'. Choose from {list(THRESHOLDS)}.")

    spec = THRESHOLDS[signal]
    breached = value >= spec["threshold"] if spec["higher_is_worse"] else value <= spec["threshold"]

    return {
        "signal": signal,
        "measured_value": value,
        "threshold": spec["threshold"],
        "unit": spec["unit"],
        "anomaly": breached,
        "verdict": "ANOMALY" if breached else "NORMAL",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Detect an anomaly in a single signal")
    parser.add_argument("--signal", required=True, choices=list(THRESHOLDS))
    parser.add_argument("--value", required=True, type=float, help="Measured value for the signal")
    args = parser.parse_args()

    result = detect(args.signal, args.value)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
