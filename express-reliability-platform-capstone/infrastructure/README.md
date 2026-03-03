# Infrastructure Deployment Guide

> **Production-grade EKS platform deployed with Terraform, Helm, and ArgoCD**
> 
> Security-first approach: OPA policy enforcement, Trivy container scanning, Snyk dependency auditing

---

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Architecture Overview](#architecture-overview)
3. [Pre-Deployment Setup](#pre-deployment-setup)
4. [Terraform Deployment](#terraform-deployment)
5. [ArgoCD Installation](#argocd-installation)
6. [Application Deployment](#application-deployment)
7. [Security Pipeline](#security-pipeline)
8. [Validation](#validation)
9. [Troubleshooting](#troubleshooting)
10. [Cleanup](#cleanup)

---

## Prerequisites

### Required Tools
```bash
# Terraform
terraform --version  # ≥ 1.5.0

# AWS CLI
aws --version  # ≥ 2.13.0

# kubectl
kubectl version --client  # ≥ 1.28.0

# Helm
helm version  # ≥ 3.12.0

# ArgoCD CLI
argocd version --client  # ≥ 2.9.0

# OPA
opa version  # ≥ 0.58.0
```

### AWS Requirements
- AWS account with admin access
- AWS CLI configured: `aws configure`
- S3 bucket for Terraform state: `express-platform-terraform-state`
- DynamoDB table for state locking: `terraform-state-lock`

### GitHub Requirements
- Repository: `YOUR_ORG/express-reliability-platform-capstone`
- GitHub Actions enabled
- Secrets configured:
  - `AWS_ACCOUNT_ID`
  - `SNYK_TOKEN`
  - `ARGOCD_SERVER`
  - `ARGOCD_PASSWORD`

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         GitHub Actions                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ Trivy Scan   │  │ Snyk Scan    │  │ OPA Policy   │          │
│  │ (Containers) │  │ (Dependencies)│  │ (Manifests)  │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
│         │                 │                 │                   │
│         └─────────────────┴─────────────────┘                   │
│                           │                                     │
│                  ┌────────▼────────┐                            │
│                  │  Build & Push   │                            │
│                  │  to ECR         │                            │
│                  └────────┬────────┘                            │
└──────────────────────────┼─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                        AWS EKS Cluster                          │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                      ArgoCD                              │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │   │
│  │  │ node-api     │  │ flask-api    │  │ web-ui       │  │   │
│  │  │ (Port 3000)  │  │ (Port 5000)  │  │ (Port 80)    │  │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              OPA Gatekeeper (Admission Control)          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  VPC: 10.0.0.0/16 | Multi-AZ | Private/Public Subnets          │
└─────────────────────────────────────────────────────────────────┘
```

---

## Pre-Deployment Setup

### 1. Create Terraform Backend
```bash
# Navigate to infrastructure directory
cd infrastructure/terraform/environments/live

# Create S3 bucket for state
aws s3api create-bucket \
  --bucket express-platform-terraform-state \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket express-platform-terraform-state \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1
```

### 2. Create ECR Repositories
```bash
# Create repositories for each service
aws ecr create-repository --repository-name express-platform-node-api --region us-east-1
aws ecr create-repository --repository-name express-platform-flask-api --region us-east-1
aws ecr create-repository --repository-name express-platform-web-ui --region us-east-1
```

### 3. Configure OIDC for GitHub Actions
```bash
# Run the OIDC provisioning script
cd ../../../../scripts
chmod +x provision_iam_oidc.sh
./provision_iam_oidc.sh
```

---

## Terraform Deployment

### Step 1: Initialize Terraform
```bash
cd ../infrastructure/terraform/environments/live

terraform init
```

**Expected Output:**
```
Terraform has been successfully initialized!
```

### Step 2: Plan Infrastructure
```bash
terraform plan -out=tfplan

# Review the plan:
# - VPC with 3 public and 3 private subnets across 3 AZs
# - EKS cluster with OIDC provider
# - 2 managed node groups (on-demand + spot)
# - Security groups with least privilege
# - KMS keys for encryption
```

### Step 3: Apply Infrastructure
```bash
terraform apply tfplan

# This takes ~15-20 minutes
# Resources created:
# - aws_vpc.main
# - aws_eks_cluster.main (10-15 min)
# - aws_eks_node_group.general
# - aws_eks_node_group.spot
```

### Step 4: Update kubeconfig
```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name express-platform-eks-live
```

**Validation:**
```bash
kubectl cluster-info
kubectl get nodes

# Expected: 3-6 nodes in Ready state
```

---

## ArgoCD Installation

### Install ArgoCD via Helm
```bash
# Add ArgoCD Helm repository
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Create argocd namespace
kubectl create namespace argocd

# Install ArgoCD
helm install argocd argo/argo-cd \
  --namespace argocd \
  --set configs.params."server\.insecure"=true \
  --set server.service.type=LoadBalancer
```

### Get ArgoCD Admin Password
```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo
```

### Access ArgoCD UI
```bash
# Get LoadBalancer URL
kubectl get svc argocd-server -n argocd

# Open in browser: http://<EXTERNAL-IP>
# Username: admin
# Password: <from previous command>
```

### Install OPA Gatekeeper
```bash
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.14/deploy/gatekeeper.yaml

# Wait for pods to be ready
kubectl wait --for=condition=Ready pod -l control-plane=controller-manager \
  -n gatekeeper-system --timeout=300s
```

---

## Application Deployment

### Method 1: ArgoCD ApplicationSet (Recommended)
```bash
# Apply ArgoCD project
kubectl apply -f ../../argocd/project.yaml

# Apply ApplicationSet (deploys all 3 services)
kubectl apply -f ../../argocd/applicationsets/platform-services.yaml

# Monitor deployment
argocd app list
argocd app get node-api
argocd app get flask-api
argocd app get web-ui
```

### Method 2: Individual Applications
```bash
# Deploy services one by one
kubectl apply -f ../../argocd/applications/node-api.yaml

# Sync manually
argocd app sync node-api --prune
argocd app wait node-api --health --timeout 300
```

### Method 3: Manual Helm Install (Development)
```bash
# Install each chart directly
helm install node-api ../../helm/charts/node-api \
  --namespace express-platform \
  --create-namespace

helm install flask-api ../../helm/charts/flask-api \
  --namespace express-platform

helm install web-ui ../../helm/charts/web-ui \
  --namespace express-platform
```

---

## Security Pipeline

### GitHub Actions Workflow Stages

#### Stage 1: Security Scanning
- **Trivy filesystem scan**: Checks code for vulnerabilities
- **Snyk dependency scan**: Audits npm/pip packages
- **Results**: Uploaded to GitHub Security tab

#### Stage 2: OPA Policy Check
- **Policy validation**: Enforces Kubernetes best practices
- **Rules**:
  - No root containers
  - Required resource limits
  - Health probes mandatory
  - Read-only root filesystem
  - No privileged containers

#### Stage 3: Build & Scan Images
- **Build**: Docker images for all services
- **Trivy image scan**: Checks container for CVEs (fails on HIGH/CRITICAL)
- **Snyk container scan**: Validates base images
- **Push to ECR**: Only if all scans pass

#### Stage 4: Deploy via ArgoCD
- **Update image tags**: Sets new SHA in ArgoCD apps
- **Sync applications**: Triggers GitOps deployment
- **Wait for health**: Ensures pods are ready

#### Stage 5: Compliance Check
- **OPA Gatekeeper audit**: Checks for policy violations
- **Report generation**: Creates compliance summary

### Trigger Pipeline
```bash
# Push to main branch
git add .
git commit -m "Deploy to production"
git push origin main

# Monitor in GitHub Actions
# https://github.com/YOUR_ORG/express-reliability-platform-capstone/actions
```

---

## Validation

### Check Infrastructure
```bash
# VPC
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=express-platform-vpc-live"

# EKS Cluster
aws eks describe-cluster --name express-platform-eks-live --region us-east-1

# Nodes
kubectl get nodes -o wide
```

### Check Applications
```bash
# Pods
kubectl get pods -n express-platform

# Expected output:
# node-api-xxxxxxxxxx-xxxxx    1/1  Running
# flask-api-xxxxxxxxxx-xxxxx   1/1  Running
# web-ui-xxxxxxxxxx-xxxxx      1/1  Running

# Services
kubectl get svc -n express-platform

# Ingress
kubectl get ingress -n express-platform -o wide
```

### Check ArgoCD Sync Status
```bash
argocd app list

# Expected: Synced and Healthy for all apps
```

### Check Security Policies
```bash
# OPA Gatekeeper constraints
kubectl get constraints -A

# Test policy (should fail)
kubectl run test-root --image=nginx --restart=Never \
  --namespace=express-platform -- sh -c "sleep 3600"

# Expected: Admission denied (policy violation)
```

### Load Testing
```bash
# Get ALB endpoint
kubectl get ingress -n express-platform

# Test node-api
curl http://<ALB-ENDPOINT>/api/health

# Test flask-api
curl http://<ALB-ENDPOINT>/flask/health

# Test web-ui
curl http://<ALB-ENDPOINT>/
```

---

## Troubleshooting

### Issue: Terraform apply fails
```bash
# Check AWS credentials
aws sts get-caller-identity

# Check backend access
aws s3 ls s3://express-platform-terraform-state

# Re-initialize
terraform init -reconfigure
```

### Issue: ArgoCD app out of sync
```bash
# Force sync
argocd app sync <app-name> --force --prune

# Check logs
kubectl logs -n argocd deployment/argocd-application-controller
```

### Issue: Pods stuck in Pending
```bash
# Check node resources
kubectl top nodes

# Check pod events
kubectl describe pod <pod-name> -n express-platform

# Scale node group
aws eks update-nodegroup-config \
  --cluster-name express-platform-eks-live \
  --nodegroup-name general-node-group \
  --scaling-config desiredSize=5
```

### Issue: OPA policy blocks deployment
```bash
# Review policy violations
kubectl get constraints -A -o json | \
  jq '.items[] | select(.status.totalViolations > 0)'

# Temporarily disable (NOT for production)
kubectl delete constraint <constraint-name>

# Fix manifest and redeploy
```

### Issue: Trivy/Snyk scan failures
```bash
# Review scan results
# GitHub > Security > Code scanning alerts

# Update base images
# Edit Dockerfile with patched versions

# Re-run pipeline
```

---

## Cleanup

### Destroy Applications
```bash
# Delete ArgoCD apps
argocd app delete node-api flask-api web-ui --cascade

# Or delete via kubectl
kubectl delete -f ../../argocd/applicationsets/platform-services.yaml
kubectl delete namespace express-platform
```

### Destroy ArgoCD
```bash
helm uninstall argocd -n argocd
kubectl delete namespace argocd
```

### Destroy Terraform Infrastructure
```bash
cd infrastructure/terraform/environments/live

terraform destroy

# Confirm: yes

# If stuck on NAT gateway deletion:
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=<vpc-id>"
aws ec2 delete-nat-gateway --nat-gateway-id <nat-id>
```

### Delete ECR Repositories
```bash
aws ecr delete-repository --repository-name express-platform-node-api --force
aws ecr delete-repository --repository-name express-platform-flask-api --force
aws ecr delete-repository --repository-name express-platform-web-ui --force
```

### Delete Terraform State
```bash
aws s3 rb s3://express-platform-terraform-state --force
aws dynamodb delete-table --table-name terraform-state-lock
```

---

## Key Files Reference

| File | Purpose |
|------|---------|
| `terraform/modules/vpc/main.tf` | Multi-AZ VPC with public/private subnets |
| `terraform/modules/eks/main.tf` | EKS cluster with OIDC, KMS encryption |
| `terraform/environments/live/main.tf` | Live environment orchestration |
| `helm/charts/node-api/` | Node.js API Helm chart |
| `argocd/applicationsets/platform-services.yaml` | Multi-service GitOps deployment |
| `.github/workflows/ci-cd-pipeline.yaml` | Security scanning + deployment automation |
| `policies/opa/kubernetes.rego` | Pod security policies |

---

## Security Defaults

✅ **Encryption**: EKS secrets encrypted with KMS  
✅ **OIDC**: No static AWS credentials in CI/CD  
✅ **RBAC**: Least privilege service accounts  
✅ **Network**: Private subnets for workloads  
✅ **Admission Control**: OPA Gatekeeper policies  
✅ **Vulnerability Scanning**: Trivy + Snyk in pipeline  
✅ **Image Registry**: Only approved ECR repositories  
✅ **Container Security**: Non-root, read-only filesystem  

---

## Next Steps

1. **Set up monitoring**: Deploy Prometheus/Grafana from v04
2. **Configure backups**: Velero for cluster state
3. **Enable autoscaling**: Cluster Autoscaler + HPA
4. **Add observability**: Integrate with Datadog/New Relic
5. **DR planning**: Multi-region failover with Route 53

---

**Questions?** Review the [capstone README](../README.md) or check the [reference architecture](../docs/reference-architecture.md).
