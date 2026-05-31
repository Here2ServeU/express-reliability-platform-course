#!/usr/bin/env python3
"""
Alerting — send a rich AIOps alert to Slack via Incoming Webhook.

The alert names the EXACT command the on-call engineer runs to resolve the
incident, so resolution is one copy-paste away from the alert itself.

Required environment variable (for real sends):
  SLACK_WEBHOOK_URL - Incoming Webhook URL from your Slack App settings

Usage:
  python3 alerting/send_slack_alert.py --evidence-file artifacts/evidence/INC-LATENCY.json
  python3 alerting/send_slack_alert.py --dry-run --evidence-file artifacts/evidence/INC-LATENCY.json
  python3 alerting/send_slack_alert.py --message "Manual SEV1 note"

Without SLACK_WEBHOOK_URL (or with --dry-run) the message is printed instead of
sent, so it is safe to run in CI/CD with no credentials.
"""

import os
import json
import argparse
import urllib.request

SEVERITY_ICON = {"high": ":rotating_light:", "medium": ":warning:", "low": ":white_check_mark:"}


def load_evidence(path: str) -> dict:
    with open(path) as f:
        return json.load(f)


def build_message(args: argparse.Namespace) -> str:
    if args.evidence_file:
        e = load_evidence(args.evidence_file)
        sev = e.get("severity", "low")
        icon = SEVERITY_ICON.get(sev, ":bell:")
        resolve = e.get("resolve_command", "see runbook")
        return (
            f"{icon} *AIOps Alert — {sev.upper()}*\n"
            f"*Incident:* {e.get('incident_id', 'N/A')}\n"
            f"*Service:* {e.get('service', 'N/A')}\n"
            f"*Signal:* {e.get('signal', 'N/A')}\n"
            f"*Risk Score:* {e.get('risk_score', 'N/A')}/100\n"
            f"*Summary:* {e.get('summary', 'N/A')}\n"
            f"*Recommended action:* {e.get('recommended_action', 'N/A')}\n"
            f":hammer_and_wrench: *Resolve by running:* `{resolve}`\n"
            f"*Owner:* {e.get('owner', 'N/A')}  |  *At:* {e.get('generated_at_utc', 'N/A')}"
        )
    return args.message or "Alert from Express Reliability Platform V10"


def send_webhook(webhook_url: str, text: str) -> None:
    payload = json.dumps({"text": text}).encode("utf-8")
    req = urllib.request.Request(
        webhook_url,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req) as resp:
        if resp.status != 200:
            raise RuntimeError(f"Slack webhook returned HTTP {resp.status}")
    print("Slack alert sent.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Send a rich AIOps Slack alert")
    parser.add_argument("--message", help="Plain text message to send")
    parser.add_argument("--evidence-file", help="Path to AIOps evidence JSON file")
    parser.add_argument("--dry-run", action="store_true", help="Print without sending")
    args = parser.parse_args()

    message = build_message(args)
    webhook_url = os.environ.get("SLACK_WEBHOOK_URL", "")

    if args.dry_run or not webhook_url:
        print("[DRY RUN] Slack message:\n")
        print(message)
        if not webhook_url:
            print("\nSet SLACK_WEBHOOK_URL to send for real.")
        return

    send_webhook(webhook_url, message)


if __name__ == "__main__":
    main()
