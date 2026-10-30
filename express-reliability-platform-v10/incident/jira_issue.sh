#!/bin/bash
set -e

JIRA_URL=${JIRA_URL:-'https://YOUR-DOMAIN.atlassian.net'}
JIRA_EMAIL=${JIRA_EMAIL:-'your@email.com'}
JIRA_TOKEN=${JIRA_TOKEN:-'YOUR_API_TOKEN'}
JIRA_PROJECT=${JIRA_PROJECT:-'RELIAB'}

SUMMARY=${1:-'Incident: platform alert fired'}
DESCRIPTION=${2:-'An automated alert fired from the reliability platform.'}
PRIORITY=${3:-'High'}   # Highest, High, Medium, Low, Lowest
LABEL=${4:-'incident'}

RESPONSE=$(curl -s -w '\nHTTP:%{http_code}' \
  -X POST \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json' \
  --user "${JIRA_EMAIL}:${JIRA_TOKEN}" \
  "${JIRA_URL}/rest/api/3/issue" \
  -d "{
    \"fields\": {
      \"project\": { \"key\": \"${JIRA_PROJECT}\" },
      \"issuetype\": { \"name\": \"Bug\" },
      \"summary\": \"${SUMMARY}\",
      \"description\": {
        \"type\": \"doc\",
        \"version\": 1,
        \"content\": [{
          \"type\": \"paragraph\",
          \"content\": [{ \"type\": \"text\", \"text\": \"${DESCRIPTION}\" }]
        }]
      },
      \"priority\": { \"name\": \"${PRIORITY}\" },
      \"labels\": [\"${LABEL}\", \"automated\", \"reliability-platform\"]
    }
  }")

HTTP_CODE=$(echo "$RESPONSE" | tail -1 | cut -d: -f2)
BODY=$(echo "$RESPONSE" | head -1)

if [ "$HTTP_CODE" -eq 201 ]; then
  ISSUE_KEY=$(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['key'])")
  echo "Jira issue created: ${ISSUE_KEY}"
  echo "View at: ${JIRA_URL}/browse/${ISSUE_KEY}"
  echo "${ISSUE_KEY}" > /tmp/jira_issue_key.txt
else
  echo "ERROR: Jira issue creation failed (HTTP ${HTTP_CODE})"
  echo "$BODY"
  exit 1
fi
