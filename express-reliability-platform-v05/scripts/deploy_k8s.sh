#!/bin/bash
set -e
# Applies all Kubernetes manifests, replacing the YOUR_ACCOUNT_ID image
# placeholder with your real AWS account ID so the pods can pull from ECR.
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=us-east-1

echo "Using ECR account: ${ACCOUNT_ID} (${REGION})"

# Namespace and config first
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml

# Substitute the placeholder and apply each manifest. Apply files one at a time:
# piping several YAML files together without '---' separators merges them into a
# single (broken) document, so only the last file would actually get applied.
for SVC in flask-api node-api web-ui; do
  echo "Deploying: ${SVC}"
  for f in k8s/${SVC}/*.yaml; do
    sed "s|YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com|${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com|g" \
      "$f" | kubectl apply -f -
  done
done

# Ingress last (provisions the ALB)
kubectl apply -f k8s/ingress.yaml

echo "Done. Watch rollout: kubectl get pods -n reliability -w"
