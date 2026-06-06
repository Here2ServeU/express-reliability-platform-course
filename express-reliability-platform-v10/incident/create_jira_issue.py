#!/usr/bin/env python3
"""
Create a Jira issue from an AIOps evidence JSON file.

Required environment variables:
  JIRA_BASE_URL  - e.g. https://your-org.atlassian.net
  JIRA_USER      - Jira account email address
  JIRA_API_TOKEN - Jira API token
  JIRA_PROJECT   - Jira project key (e.g. OPS, SRE, PLAT)

How to get a free Jira instance for practice:
  1. Register at https://www.atlassian.com/software/jira/free
  2. Create a project (e.g. key=OPS, type=Scrum or Kanban)
  3. Generate an API token at https://id.atlassian.com/manage-profile/security/api-tokens
  4. Export credentials:
       export JIRA_BASE_URL=https://your-org.atlassian.net
       export JIRA_USER=you@example.com
       export JIRA_API_TOKEN=your_token_here
       export JIRA_PROJECT=OPS

Usage:
  python3 itsm/create_jira_issue.py --evidence-file artifacts/aiops/evidence/local/INC-001.json
  python3 itsm/create_jira_issue.py --dry-run --evidence-file artifacts/aiops/evidence/local/INC-001.json
"""

import os
import sys
import json
import base64
import argparse
import urllib.request

PRIORITY_MAP = {"high": "High", "medium": "Medium", "low": "Low"}


def load_evidence(path: str) -> dict:
    with open(path) as f:
        return json.load(f)


def build_issue_payload(evidence: dict, project_key: str) -> dict:
    sev = evidence.get("severity", "low")
    description_text = (
        f"Incident ID : {evidence.get('incident_id', 'N/A')}\n"
        f"Service     : {evidence.get('service', 'N/A')}\n"
        f"Risk Score  : {evidence.get('risk_score', 'N/A')}\n"
        f"Latency ms  : {evidence.get('latency_ms', 'N/A')}\n"
        f"Error Rate %: {evidence.get('error_rate_pct', 'N/A')}\n"
        f"Restarts    : {evidence.get('restart_count', 'N/A')}\n"
        f"Action      : {evidence.get('recommended_action', 'N/A')}\n"
        f"Owner       : {evidence.get('owner', 'N/A')}\n"
        f"Generated   : {evidence.get('generated_at_utc', 'N/A')}"
    )
    return {
        "fields": {
            "project": {"key": project_key},
            "summary": (
                f"AIOps: {sev.upper()} severity detected on {evidence.get('service', 'unknown')}"
            ),
            # Jira Cloud uses Atlassian Document Format (ADF) for rich text
            "description": {
                "type": "doc",
                "version": 1,
                "content": [
                    {
                        "type": "codeBlock",
                        "attrs": {"language": "text"},
                        "content": [{"type": "text", "text": description_text}],
                    }
                ],
            },
            "issuetype": {"name": "Bug"},
            "priority": {"name": PRIORITY_MAP.get(sev, "Low")},
            "labels": ["aiops", "reliability", evidence.get("service", "unknown")],
        }
    }


def create_issue(base_url: str, user: str, token: str, payload: dict) -> None:
    url = f"{base_url.rstrip('/')}/rest/api/3/issue"
    credentials = base64.b64encode(f"{user}:{token}".encode()).decode()
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=body,
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json",
            "Authorization": f"Basic {credentials}",
        },
        method="POST",
    )
    with urllib.request.urlopen(req) as resp:
        result = json.loads(resp.read())
    key = result.get("key", "N/A")
    print(f"Jira issue created: {key}")
    print(f"View at: {base_url.rstrip('/')}/browse/{key}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Create a Jira issue from AIOps evidence"
    )
    parser.add_argument("--evidence-file", required=True, help="Path to AIOps evidence JSON file")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print issue payload without making an API call",
    )
    args = parser.parse_args()

    evidence = load_evidence(args.evidence_file)
    project_key = os.environ.get("JIRA_PROJECT", "OPS")
    payload = build_issue_payload(evidence, project_key)

    if args.dry_run:
        print("[DRY RUN] Jira issue payload:\n")
        print(json.dumps(payload, indent=2))
        return

    base_url = os.environ.get("JIRA_BASE_URL", "")
    user     = os.environ.get("JIRA_USER", "")
    token    = os.environ.get("JIRA_API_TOKEN", "")

    if not all([base_url, user, token]):
        print(
            "Error: JIRA_BASE_URL, JIRA_USER, and JIRA_API_TOKEN must all be set.\n"
            "Run with --dry-run to preview the payload without credentials."
        )
        sys.exit(1)

    create_issue(base_url, user, token, payload)


if __name__ == "__main__":
    main()
