#!/usr/bin/env python3
"""
Alerting bridge — Alertmanager webhook -> Slack.

Prometheus Alertmanager POSTs firing/resolved alerts to this small HTTP server.
For each alert it builds a Slack message that includes the `resolve_command`
annotation defined in monitoring/alert.rules.yml, so the on-call engineer can
fix the incident by running one script straight from the alert.

Run it:
  python3 alerting/alertmanager_webhook.py
  # listens on 0.0.0.0:5001, path /alerts (matches monitoring/alertmanager/alertmanager.yml)

Behavior:
  - If SLACK_WEBHOOK_URL is set, it forwards each alert to Slack.
  - Otherwise it prints the message (dry-run), so it works with no credentials.

This uses only the Python standard library — no pip install required.
"""

import os
import json
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT = int(os.environ.get("WEBHOOK_PORT", "5001"))
SLACK_WEBHOOK_URL = os.environ.get("SLACK_WEBHOOK_URL", "")

SEVERITY_ICON = {"critical": ":rotating_light:", "warning": ":warning:", "info": ":bell:"}


def format_alert(alert: dict) -> str:
    labels = alert.get("labels", {})
    annotations = alert.get("annotations", {})
    status = alert.get("status", "firing")
    sev = labels.get("severity", "info")
    icon = SEVERITY_ICON.get(sev, ":bell:") if status == "firing" else ":white_check_mark:"
    resolve = annotations.get("resolve_command", "see runbook")

    lines = [
        f"{icon} *{labels.get('alertname', 'Alert')}* — {status.upper()} ({sev})",
        f"*Service:* {labels.get('job', 'N/A')}",
        f"*Summary:* {annotations.get('summary', 'N/A')}",
        f"*Detail:* {annotations.get('description', 'N/A')}",
    ]
    if status == "firing":
        lines.append(f":hammer_and_wrench: *Resolve by running:* `{resolve}`")
    return "\n".join(lines)


def post_to_slack(text: str) -> None:
    if not SLACK_WEBHOOK_URL:
        print("[DRY RUN] Slack message:\n" + text + "\n")
        return
    payload = json.dumps({"text": text}).encode("utf-8")
    req = urllib.request.Request(
        SLACK_WEBHOOK_URL,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req) as resp:
        if resp.status != 200:
            print(f"Slack webhook returned HTTP {resp.status}")
        else:
            print("Forwarded alert to Slack.")


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):  # noqa: N802 (http.server API)
        if self.path != "/alerts":
            self.send_response(404)
            self.end_headers()
            return

        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length) if length else b"{}"
        try:
            body = json.loads(raw or b"{}")
        except json.JSONDecodeError:
            self.send_response(400)
            self.end_headers()
            return

        for alert in body.get("alerts", []):
            post_to_slack(format_alert(alert))

        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok")

    def log_message(self, *args):  # quieter default logging
        return


def main() -> None:
    mode = "forwarding to Slack" if SLACK_WEBHOOK_URL else "DRY RUN (set SLACK_WEBHOOK_URL to forward)"
    print(f"Alertmanager->Slack bridge listening on 0.0.0.0:{PORT}/alerts — {mode}")
    HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()
