#!/usr/bin/env python3
"""
FinOps — AWS cost report via Cost Explorer.

Pulls the last N days of unblended cost grouped by service and prints a ranked
report plus the total. This is the "where is the money going" view a platform
engineer checks before and after a change.

Requires AWS credentials (e.g. `aws configure`) and the Cost Explorer API
enabled for the account. Uses boto3 if available; otherwise falls back to the
AWS CLI. With neither, runs a sample report so the workflow is still teachable.

Usage:
  python3 finops/check_costs.py
  python3 finops/check_costs.py --days 7
  python3 finops/check_costs.py --granularity MONTHLY
  python3 finops/check_costs.py --sample        # no credentials needed
"""

import argparse
import datetime as dt
import json
import subprocess


def date_range(days: int):
    end = dt.date.today()
    start = end - dt.timedelta(days=days)
    return start.isoformat(), end.isoformat()


def fetch_with_boto3(start: str, end: str, granularity: str):
    import boto3  # imported lazily so --sample works without boto3

    ce = boto3.client("ce")
    resp = ce.get_cost_and_usage(
        TimePeriod={"Start": start, "End": end},
        Granularity=granularity,
        Metrics=["UnblendedCost"],
        GroupBy=[{"Type": "DIMENSION", "Key": "SERVICE"}],
    )
    totals = {}
    for period in resp.get("ResultsByTime", []):
        for group in period.get("Groups", []):
            service = group["Keys"][0]
            amount = float(group["Metrics"]["UnblendedCost"]["Amount"])
            totals[service] = totals.get(service, 0.0) + amount
    return totals


def fetch_with_cli(start: str, end: str, granularity: str):
    cmd = [
        "aws", "ce", "get-cost-and-usage",
        "--time-period", f"Start={start},End={end}",
        "--granularity", granularity,
        "--metrics", "UnblendedCost",
        "--group-by", "Type=DIMENSION,Key=SERVICE",
        "--output", "json",
    ]
    raw = subprocess.run(cmd, capture_output=True, text=True, check=True).stdout
    data = json.loads(raw)
    totals = {}
    for period in data.get("ResultsByTime", []):
        for group in period.get("Groups", []):
            service = group["Keys"][0]
            amount = float(group["Metrics"]["UnblendedCost"]["Amount"])
            totals[service] = totals.get(service, 0.0) + amount
    return totals


SAMPLE = {
    "Amazon Elastic Container Service for Kubernetes": 142.10,
    "Amazon Elastic Compute Cloud - Compute": 88.44,
    "Amazon Virtual Private Cloud": 31.20,
    "Amazon Elastic Load Balancing": 18.05,
    "AmazonCloudWatch": 9.77,
    "Amazon Simple Storage Service": 4.31,
}


def report(totals: dict, currency: str = "USD") -> None:
    if not totals:
        print("No cost data returned for the period.")
        return
    ranked = sorted(totals.items(), key=lambda kv: kv[1], reverse=True)
    grand = sum(totals.values())
    width = max(len(s) for s, _ in ranked)
    print(f"{'Service'.ljust(width)}   Cost ({currency})")
    print("-" * (width + 16))
    for service, amount in ranked:
        print(f"{service.ljust(width)}   {amount:>10.2f}")
    print("-" * (width + 16))
    print(f"{'TOTAL'.ljust(width)}   {grand:>10.2f}")


def main() -> None:
    parser = argparse.ArgumentParser(description="AWS cost report (FinOps)")
    parser.add_argument("--days", type=int, default=30, help="Look-back window in days")
    parser.add_argument("--granularity", default="DAILY", choices=["DAILY", "MONTHLY"])
    parser.add_argument("--sample", action="store_true", help="Print a sample report (no AWS calls)")
    args = parser.parse_args()

    start, end = date_range(args.days)
    print(f"AWS cost report  {start} -> {end}  ({args.granularity})\n")

    if args.sample:
        report(SAMPLE)
        print("\n[sample data] Run without --sample once AWS credentials are configured.")
        return

    try:
        totals = fetch_with_boto3(start, end, args.granularity)
    except ImportError:
        try:
            totals = fetch_with_cli(start, end, args.granularity)
        except Exception as exc:  # noqa: BLE001 — fall back to sample for teaching
            print(f"Could not query Cost Explorer ({exc}). Showing sample data.\n")
            report(SAMPLE)
            return
    except Exception as exc:  # noqa: BLE001
        print(f"Could not query Cost Explorer ({exc}). Showing sample data.\n")
        report(SAMPLE)
        return

    report(totals)


if __name__ == "__main__":
    main()
