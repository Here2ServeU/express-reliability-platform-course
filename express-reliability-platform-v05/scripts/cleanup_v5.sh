#!/bin/bash
echo '=== V5 Cleanup ==='
docker compose down
docker volume rm express-reliability-platform-v05_grafana-data 2>/dev/null || true
docker system prune -f
terraform -chdir=terraform/platform destroy -auto-approve 2>/dev/null || true
echo 'Remaining volumes:'
docker volume ls | grep grafana || echo '  No grafana volumes — good.'
echo '=== Done! Bootstrap S3 + DynamoDB kept. ==='
