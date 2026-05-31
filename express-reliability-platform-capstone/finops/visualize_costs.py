#!/usr/bin/env python3
"""
FinOps — visualize a cost breakdown as a terminal bar chart.

Reads a JSON map of {service: amount} (from check_costs.py output you saved, or
any cost export) and prints a proportional ASCII bar chart so cost hot-spots are
obvious at a glance — no plotting libraries required.

Usage:
  # Pipe or pass a JSON file of {"service": amount, ...}
  python3 finops/visualize_costs.py --file costs.json
  python3 finops/visualize_costs.py --sample
"""

import argparse
import json
import sys

SAMPLE = {
    "EKS": 142.10,
    "EC2": 88.44,
    "VPC": 31.20,
    "ELB": 18.05,
    "CloudWatch": 9.77,
    "S3": 4.31,
}


def load(path: str) -> dict:
    if path == "-":
        return json.load(sys.stdin)
    with open(path) as f:
        return json.load(f)


def chart(totals: dict, width: int = 40) -> None:
    if not totals:
        print("No cost data to visualize.")
        return
    ranked = sorted(totals.items(), key=lambda kv: kv[1], reverse=True)
    top = ranked[0][1] or 1
    grand = sum(totals.values()) or 1
    label_w = max(len(s) for s, _ in ranked)
    for service, amount in ranked:
        bars = int((amount / top) * width)
        pct = (amount / grand) * 100
        print(f"{service.ljust(label_w)} | {'#' * bars:<{width}} {amount:>9.2f}  ({pct:4.1f}%)")
    print(f"\nTotal: {grand:.2f}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Visualize AWS costs as a bar chart (FinOps)")
    parser.add_argument("--file", help="JSON file of {service: amount}; use '-' for stdin")
    parser.add_argument("--sample", action="store_true", help="Use sample data")
    args = parser.parse_args()

    if args.sample or not args.file:
        if not args.file:
            print("[sample data] Pass --file costs.json to visualize real data.\n")
        chart(SAMPLE)
        return

    chart(load(args.file))


if __name__ == "__main__":
    main()
