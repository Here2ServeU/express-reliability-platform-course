#!/bin/bash
set -e

SN_INSTANCE=${SN_INSTANCE:-'devXXXXXX'}
SN_USER=${SN_USER:-'admin'}
SN_PASS=${SN_PASS:-'YOUR_SN_PASSWORD'}
SN_URL="https://${SN_INSTANCE}.service-now.com"

SHORT_DESCRIPTION=${1:-'Platform alert: service degraded'}
DESCRIPTION=${2:-'An automated alert fired from the reliability platform.'}
URGENCY=${3:-'2'}   # 1=Critical, 2=High, 3=Medium, 4=Low
SERVICE=${4:-'reliability-platform'}

# Create the incident via the Table API
RESPONSE=$(curl -s -w '\nHTTP:%{http_code}' \
  -X POST \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json' \
  --user "${SN_USER}:${SN_PASS}" \
  "${SN_URL}/api/now/table/incident" \
  -d "{
    \"short_description\": \"${SHORT_DESCRIPTION}\",
    \"description\": \"${DESCRIPTION}\",
    \"urgency\": \"${URGENCY}\",
    \"category\": \"software\",
    \"subcategory\": \"application\",
    \"assignment_group\": \"Service Desk\",
    \"cmdb_ci\": \"${SERVICE}\"
  }")

HTTP_CODE=$(echo "$RESPONSE" | tail -1 | cut -d: -f2)
BODY=$(echo "$RESPONSE" | head -1)

if [ "$HTTP_CODE" -eq 201 ]; then
  # Extract the incident number and sys_id from the JSON response
  INC_NUMBER=$(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['result']['number'])")
  SYS_ID=$(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['result']['sys_id'])")
  echo "ServiceNow incident created: ${INC_NUMBER} (sys_id: ${SYS_ID})"
  echo "${SYS_ID}" > /tmp/sn_sys_id.txt   # Save for later update/close
else
  echo "ERROR: ServiceNow ticket creation failed (HTTP ${HTTP_CODE})"
  echo "Response: $BODY"
  exit 1
fi
