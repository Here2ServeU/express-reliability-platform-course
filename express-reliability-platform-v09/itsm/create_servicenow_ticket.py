#!/usr/bin/env python3
"""
Create a ServiceNow incident ticket from an AIOps evidence JSON file.

Required environment variables:
  SNOW_INSTANCE  - ServiceNow instance name (e.g. dev12345, from https://developer.servicenow.com)
  SNOW_USER      - ServiceNow username (use a dedicated service account)
  SNOW_PASSWORD  - ServiceNow password

How to get a free ServiceNow instance for practice:
  1. Register at https://developer.servicenow.com
  2. Request a Personal Developer Instance (PDI)
  3. Note the instance name (e.g. dev12345) from the PDI dashboard
  4. Export credentials:
       export SNOW_INSTANCE=dev12345
       export SNOW_USER=admin
       export SNOW_PASSWORD=your_pdi_password

Usage:
  python3 itsm/create_servicenow_ticket.py --evidence-file artifacts/aiops/evidence/local/INC-001.json
  python3 itsm/create_servicenow_ticket.py --dry-run --evidence-file artifacts/aiops/evidence/local/INC-001.json
"""

import os
import sys
import json
import base64
import argparse
import urllib.request

SNOW_TABLE = "incident"

# ServiceNow impact/urgency: 1=High, 2=Medium, 3=Low
SEVERITY_NUMBER = {"high": "1", "medium": "2", "low": "3"}


def load_evidence(path: str) -> dict:
    with open(path) as f:
        return json.load(f)


def build_ticket_payload(evidence: dict) -> dict:
    sev = evidence.get("severity", "low")
    num = SEVERITY_NUMBER.get(sev, "3")
    return {
        "short_description": (
            f"AIOps: {sev.upper()} severity detected on {evidence.get('service', 'unknown')}"
        ),
        "description": (
            f"Incident ID : {evidence.get('incident_id', 'N/A')}\n"
            f"Service     : {evidence.get('service', 'N/A')}\n"
            f"Risk Score  : {evidence.get('risk_score', 'N/A')}\n"
            f"Latency ms  : {evidence.get('latency_ms', 'N/A')}\n"
            f"Error Rate %: {evidence.get('error_rate_pct', 'N/A')}\n"
            f"Restarts    : {evidence.get('restart_count', 'N/A')}\n"
            f"Action      : {evidence.get('recommended_action', 'N/A')}\n"
            f"Owner       : {evidence.get('owner', 'N/A')}\n"
            f"Generated   : {evidence.get('generated_at_utc', 'N/A')}"
        ),
        "impact": num,
        "urgency": num,
        "category": "software",
        "subcategory": "reliability",
        "assignment_group": "SRE",
        "caller_id": evidence.get("owner", "aiops-system"),
    }


def create_ticket(instance: str, user: str, password: str, payload: dict) -> None:
    url = f"https://{instance}.service-now.com/api/now/table/{SNOW_TABLE}"
    credentials = base64.b64encode(f"{user}:{password}".encode()).decode()
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
    number = result.get("result", {}).get("number", "N/A")
    sys_id  = result.get("result", {}).get("sys_id", "N/A")
    print(f"ServiceNow ticket created: {number} (sys_id={sys_id})")
    print(f"View at: https://{instance}.service-now.com/nav_to.do?uri=incident.do?sys_id={sys_id}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Create a ServiceNow incident from AIOps evidence"
    )
    parser.add_argument("--evidence-file", required=True, help="Path to AIOps evidence JSON file")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print ticket payload without making an API call",
    )
    args = parser.parse_args()

    evidence = load_evidence(args.evidence_file)
    payload = build_ticket_payload(evidence)

    if args.dry_run:
        print("[DRY RUN] ServiceNow ticket payload:\n")
        print(json.dumps(payload, indent=2))
        return

    instance = os.environ.get("SNOW_INSTANCE", "")
    user     = os.environ.get("SNOW_USER", "")
    password = os.environ.get("SNOW_PASSWORD", "")

    if not all([instance, user, password]):
        print(
            "Error: SNOW_INSTANCE, SNOW_USER, and SNOW_PASSWORD must all be set.\n"
            "Run with --dry-run to preview the payload without credentials."
        )
        sys.exit(1)

    create_ticket(instance, user, password, payload)


if __name__ == "__main__":
    main()
