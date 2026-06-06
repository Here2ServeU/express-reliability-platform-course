#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"
TAG="${IMAGE_TAG:-v8}"

for service in flask-api node-api web-ui; do
  image="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$service:$TAG"
  docker buildx build --platform linux/amd64 -t "$image" "apps/$service" --push
  echo "Pushed $image"
done
