#!/usr/bin/env bash
set -euo pipefail

SUMMARY="${1:-Reliability incident detected}"
DESCRIPTION="${2:-Created by the Express Reliability Platform incident pipeline.}"
PROJECT="${JIRA_PROJECT:-OPS}"

if [ -z "${JIRA_DOMAIN:-}" ] || [ -z "${JIRA_EMAIL:-}" ] || [ -z "${JIRA_API_TOKEN:-}" ]; then
  echo "[DRY RUN] Jira issue: $PROJECT - $SUMMARY"
  exit 0
fi

curl -sS -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X POST "https://$JIRA_DOMAIN/rest/api/3/issue" \
  --data "{\"fields\":{\"project\":{\"key\":\"$PROJECT\"},\"summary\":\"$SUMMARY\",\"issuetype\":{\"name\":\"Bug\"},\"description\":{\"type\":\"doc\",\"version\":1,\"content\":[{\"type\":\"paragraph\",\"content\":[{\"type\":\"text\",\"text\":\"$DESCRIPTION\"}]}]}}}"
echo
