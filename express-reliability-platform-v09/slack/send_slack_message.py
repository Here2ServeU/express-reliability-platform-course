#!/usr/bin/env python3
"""
Send a Slack alert via Incoming Webhook.

Required environment variable:
  SLACK_WEBHOOK_URL - the Incoming Webhook URL from your Slack App settings

How to get a Webhook URL:
  1. Go to https://api.slack.com/apps -> Create New App -> From Scratch
  2. Enable Incoming Webhooks -> Add New Webhook to Workspace
  3. Choose a channel, copy the URL
  4. Export it: export SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...

Usage:
  python3 slack/send_slack_message.py --message "SEV1 on node-api"
  python3 slack/send_slack_message.py --evidence-file artifacts/aiops/evidence/local/INC-001.json
  python3 slack/send_slack_message.py --dry-run --evidence-file artifacts/aiops/evidence/local/INC-001.json
"""

import os
import sys
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
        return (
            f"{icon} *AIOps Alert*\n"
            f"*Incident:* {e.get('incident_id', 'N/A')}\n"
            f"*Service:* {e.get('service', 'N/A')}\n"
            f"*Severity:* {sev.upper()}\n"
            f"*Risk Score:* {e.get('risk_score', 'N/A')}\n"
            f"*Action:* {e.get('recommended_action', 'N/A')}\n"
            f"*Owner:* {e.get('owner', 'N/A')}\n"
            f"*Generated:* {e.get('generated_at_utc', 'N/A')}"
        )
    return args.message or "Alert from Express Reliability Platform V9"


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
    parser = argparse.ArgumentParser(description="Send Slack alert via Incoming Webhook")
    parser.add_argument("--message", help="Plain text message to send")
    parser.add_argument("--evidence-file", help="Path to AIOps evidence JSON file")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print message without sending (safe for CI/CD without credentials)",
    )
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