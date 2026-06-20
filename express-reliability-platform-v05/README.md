# Express Reliability Platform V5: Kubernetes Self-Healing on EKS

## Version Purpose

Version 5 moves the platform from ECS to Kubernetes on Amazon EKS. Kubernetes watches the containers,
restarts failed pods, and scales deployments with the Horizontal Pod Autoscaler.

## Goal

Use Terraform to provision an EKS cluster. Deploy the three services as Kubernetes Deployments with
liveness and readiness probes. Configure HPAs. Validate self-healing by deleting a pod and watching
Kubernetes replace it within 30 seconds.

## AWS Services Provisioned

All infrastructure is provisioned with Terraform under `terraform/`. Region: `us-east-1`.

| Service | Resource | Defined in |
| --- | --- | --- |
| **Amazon EKS** | Control plane (`reliability-platform-eks`, Kubernetes 1.30) + managed node group (`t3.medium`, min 2 / desired 3 / max 6) + add-ons (vpc-cni, coredns, kube-proxy, aws-ebs-csi-driver) | [eks.tf](terraform/platform/eks.tf) |
| **Amazon ECR** | One private repository per service: `reliability-platform/flask-api`, `/node-api`, `/web-ui` | [ecr.tf](terraform/platform/ecr.tf) |
| **Amazon VPC** | VPC `10.42.0.0/16`, 2 public + 2 private subnets across 2 AZs, internet gateway, 2 NAT gateways + EIPs | [networking.tf](terraform/platform/networking.tf) |
| **IAM** | EKS cluster role, worker node role, and OIDC provider (IRSA) for the load balancer controller | [iam.tf](terraform/platform/iam.tf) |
| **Elastic Load Balancing (ALB)** | AWS Load Balancer Controller installed via Helm; provisions an ALB from the Kubernetes Ingress | [ingress.tf](terraform/platform/ingress.tf) |
| **EC2** | Worker nodes (run in private subnets, managed by the EKS node group) | [eks.tf](terraform/platform/eks.tf) |
| **S3 + DynamoDB** | Remote Terraform state bucket + state lock table (bootstrap stage) | [bootstrap/main.tf](terraform/bootstrap/main.tf) |

## Architecture

```text
Internet
   │
   ▼
Application Load Balancer (ALB)        ← created by the AWS Load Balancer Controller from k8s/ingress.yaml
   │
   ▼
EKS Cluster (reliability-platform-eks)
   ├── namespace: reliability
   │     ├── web-ui   (Deployment + Service)
   │     ├── node-api (Deployment + Service + HPA)
   │     └── flask-api(Deployment + Service + HPA)
   └── worker nodes (EC2, private subnets) ──► pull images from Amazon ECR via NAT Gateway
```

## Project Structure

```text
express-reliability-platform-v05/
├── apps/
│   ├── flask-api/
│   ├── node-api/
│   └── web-ui/
├── k8s/
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── flask-api/          # deployment.yaml, service.yaml, hpa.yaml
│   ├── node-api/           # deployment.yaml, service.yaml, hpa.yaml
│   ├── web-ui/             # deployment.yaml, service.yaml
│   └── ingress.yaml        # ALB ingress
├── monitoring/
│   ├── prometheus.yml
│   ├── alert.rules.yml
│   └── grafana-dashboard.json
├── terraform/
│   ├── bootstrap/          # S3 + DynamoDB remote state backend
│   │   ├── main.tf
│   │   └── variables.tf    # region, bucket prefix, lock table name
│   └── platform/           # VPC, EKS, ECR, IAM, ALB ingress controller
│       ├── main.tf         # backend = partial config (no account number)
│       ├── backend.hcl     # per-account state bucket name (init -backend-config)
│       └── variables.tf
├── scripts/
│   ├── push_images.sh      # build (linux/amd64) and push images to ECR
│   ├── deploy_k8s.sh       # substitute account ID + apply all k8s manifests
│   └── cleanup_v5.sh       # tear down k8s resources + terraform destroy
├── docker-compose.yml      # optional local run of the three services
└── README.md
```

## Prerequisites

- AWS CLI configured with credentials (`aws sts get-caller-identity` works)
- Terraform, kubectl, and Docker (with `buildx`) installed
- **Docker Desktop is running** — verify: `docker ps`
- Region used throughout: `us-east-1`
- **Make the helper scripts executable** (one time): `chmod +x scripts/*.sh`

## Configuration

There is **no AWS account number hardcoded in any `main.tf`**. Account- and
environment-specific values live in dedicated variables / backend files:

| What | Where | Notes |
| --- | --- | --- |
| Region, state bucket prefix, lock table name | [terraform/bootstrap/variables.tf](terraform/bootstrap/variables.tf) | All defaulted — override with `-var` or a `*.tfvars` file if needed. The account ID is auto-derived from your credentials, so the bucket name needs no editing. |
| Per-account state bucket name | [terraform/platform/backend.hcl](terraform/platform/backend.hcl) | The platform backend uses *partial configuration*. Terraform backend blocks cannot read `variables.tf`, so the account-specific bucket is set here and loaded at init with `-backend-config=backend.hcl`. Edit only the account-number suffix. |
| EKS cluster size, node type, k8s version | [terraform/platform/variables.tf](terraform/platform/variables.tf) | Defaults are sensible for the course. |

To target a different AWS account, change the account-number suffix in
`backend.hcl` to match the bucket created by `terraform/bootstrap`
(its `state_bucket` output) — nothing in `main.tf` changes.

## Run Steps

### 1. Create the remote state backend (one time)

```sh
terraform -chdir=terraform/bootstrap init
terraform -chdir=terraform/bootstrap apply
```

### 2. Provision the EKS platform

The state bucket name (which includes your AWS account ID) is supplied to the backend
via `backend.hcl`, so you never edit it in `main.tf`. Set the account suffix in
[terraform/platform/backend.hcl](terraform/platform/backend.hcl) once, then:

```sh
terraform -chdir=terraform/platform init -backend-config=backend.hcl
terraform -chdir=terraform/platform apply
```

After apply, connect kubectl to the cluster using the printed `kubeconfig_command` output:

```sh
aws eks update-kubeconfig --region us-east-1 --name reliability-platform-eks
```

### 3. Build and push images to ECR

```sh
./scripts/push_images.sh
```

### 4. Apply the Kubernetes manifests

The deployment manifests use a `YOUR_ACCOUNT_ID` image placeholder. The deploy script
replaces it with your real AWS account ID, then applies every manifest in order:

```sh
./scripts/deploy_k8s.sh
```

> If you prefer to apply manually, first substitute the account ID in the deployment
> images (`k8s/*/deployment.yaml`), otherwise the pods will fail with `ImagePullBackOff`.

**Region note:** the deploy script uses `REGION=us-east-1`, and the image references
point at `*.dkr.ecr.us-east-1.amazonaws.com`. This **must match the region where you
deployed the platform and pushed the images**. If you deployed to a different region,
update `REGION` in [scripts/deploy_k8s.sh](scripts/deploy_k8s.sh) (and
[scripts/push_images.sh](scripts/push_images.sh)) and the `us-east-1` segment in the
`k8s/*/deployment.yaml` image URLs to the same region, or the pods cannot pull from ECR.

## Test Self-Healing

```sh
kubectl get pods -n reliability
kubectl delete pod -n reliability -l app=flask-api
kubectl get pods -n reliability -w
```

Kubernetes should schedule a replacement pod and return the deployment to its desired
replica count within ~30 seconds.

## Validation Checklist

- [ ] EKS nodes are Ready (`kubectl get nodes`).
- [ ] All service pods are Running in the `reliability` namespace.
- [ ] Liveness and readiness probes are configured on each deployment.
- [ ] Deleted pods are replaced automatically.
- [ ] HPAs exist and can scale under load (`kubectl get hpa -n reliability` — the
      TARGETS column should show a percentage, not `<unknown>`; metrics-server is
      installed by Terraform to provide these metrics).
- [ ] The ALB ingress routes traffic to the web UI.

## Cleanup

Tear down the Kubernetes resources (releasing the ALB) and destroy the Terraform-managed
AWS resources. This also empties and destroys the bootstrap S3 state bucket and DynamoDB
lock table, leaving nothing running. To stand the platform back up later, re-run the
bootstrap step first (`terraform -chdir=terraform/bootstrap apply`).

```sh
./scripts/cleanup_v5.sh
```
