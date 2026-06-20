# Express Reliability Platform V8: GitOps and Governance

## Version Purpose

Version 8 adds the governance layer from the Word guide: Trivy scanning, OPA Gatekeeper policies,
Checkov infrastructure scanning, and AIOps risk scoring in the deployment workflow.

## Goal

Add Trivy image scanning to the pipeline. Install OPA Gatekeeper and enforce three policies:

- No `:latest` image tags in production.
- Resource limits required on all containers.
- Security labels required on namespaces.

Add a risk score from `0` to `100` before deployment and validate all six checks.

## Project Structure

```text
express-reliability-platform-v08/
├── apps/                         # same application services carried from V7
├── environments/                 # shared and live Terraform layers
├── infrastructure/               # bootstrap state resources
├── modules/                      # reusable Terraform modules
├── governance/
│   ├── gatekeeper/
│   │   ├── templates/            # ConstraintTemplate YAML files
│   │   └── constraints/          # Constraint YAML files
│   └── namespaces/
│       └── platform-ns.yaml
├── .github/workflows/
│   └── provision.yml             # pipeline to extend with scan and risk jobs
└── scripts/
    ├── risk_score.sh
    ├── build_push_images_v8.sh
    ├── cleanup_v8.sh
    └── terraform_init_apply.sh
```

## Prerequisites

Before running this version, confirm:

- [ ] **Terraform ≥ 1.5, kubectl ≥ 1.29, helm ≥ 3.14, and AWS CLI v2** installed.
- [ ] **Docker Desktop is running** — verify: `docker ps`.
- [ ] **AWS CLI v2 configured** with credentials for EKS, IAM, EC2, and ECR — verify: `aws sts get-caller-identity`.
- [ ] **Make the helper scripts executable** (one time):
  ```sh
  chmod +x scripts/*.sh
  ```

## Run Steps

Apply the namespace and Gatekeeper policies:

```sh
kubectl apply -f governance/namespaces/platform-ns.yaml
kubectl apply -f governance/gatekeeper/templates
kubectl apply -f governance/gatekeeper/constraints
```

Run risk scoring locally:

```sh
CHANGED_FILES=12 TRIVY_HIGH=0 TRIVY_CRITICAL=0 CHECKOV_FAILED=0 ERROR_RATE_PCT=1 ./scripts/risk_score.sh
```

Clean up governance resources:

```sh
./scripts/cleanup_v8.sh
```

## Validation Checklist

- [ ] Gatekeeper pods are running.
- [ ] A pod without resource limits is rejected.
- [ ] A pod using `:latest` is rejected.
- [ ] A namespace without required labels is rejected.
- [ ] The pipeline runs scan and risk jobs before deployment.
- [ ] `scripts/risk_score.sh` returns LOW, MEDIUM, HIGH, or CRITICAL decisions.
