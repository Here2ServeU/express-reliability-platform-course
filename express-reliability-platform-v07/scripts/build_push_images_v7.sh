#!/bin/bash
set -e

ECR_BASE=$(terraform -chdir=terraform/bootstrap output -raw ecr_base)

aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  $(echo $ECR_BASE | cut -d/ -f1)

# Use the V6 Dockerfiles for flask-api and node-api
V6_SRC=${V6_APPS_SRC:-../express-reliability-platform-v06/platform}

for SVC in flask-api node-api; do
  docker buildx build --platform linux/amd64 \
    -t ${ECR_BASE}/${SVC}:latest --push ${V6_SRC}/../apps/${SVC}
done

# web-ui from V7's apps folder
docker buildx build --platform linux/amd64 \
  -t ${ECR_BASE}/web-ui:latest --push ./apps/web-ui

echo "All three images pushed to ECR."
