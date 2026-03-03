#!/bin/bash
# Provision IAM and OIDC for GitHub Actions
set -e
AWS_REGION="us-east-1"
OIDC_PROVIDER_URL="https://token.actions.githubusercontent.com"
AUDIENCE="sts.amazonaws.com"
REPO="YOUR_GITHUB_USERNAME/express-reliability-platform-v3"
ROLE_NAME="b2m-github-actions-role"

# Create OIDC provider
aws iam create-open-id-connect-provider \
  --url "$OIDC_PROVIDER_URL" \
  --client-id-list "$AUDIENCE" \
  --thumbprint-list "9e99a48a9960b14926bb7f3b02e22da0ecd4e4c3"

# Create IAM role trust policy
cat <<EOF > trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "$AUDIENCE",
          "token.actions.githubusercontent.com:sub": "repo:$REPO:ref:refs/heads/main"
        }
      }
    }
  ]
}
EOF

# Create IAM role
aws iam create-role \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document file://trust-policy.json

# Attach policy (Admin for sandbox, least privilege for prod)
aws iam attach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn "arn:aws:iam::aws:policy/AdministratorAccess"

echo "OIDC and IAM role provisioned for GitHub Actions."