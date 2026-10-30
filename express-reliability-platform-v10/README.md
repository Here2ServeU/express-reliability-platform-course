# Express Reliability Platform V10: Multi-Cloud on Google Cloud (GKE)

## Purpose

V9 finished the platform on AWS EKS. V10 moves the **same platform** to Google Cloud.

The point is portability. The apps, Helm charts, chaos drills, incident pipeline, and governance carry over almost unchanged. Only the cloud layer is swapped: GKE in place of EKS, Artifact Registry in place of ECR, and Workload Identity in place of IAM roles for pods.

V10 also adds two things V9 did not have:

- **SLOs as code in Cloud Monitoring**, with multi-window burn-rate alerts
- **Chaos Drill 5: Error-Budget Burn**, which fails requests on purpose so you can watch the burn-rate alert fire, then measures recovery

## What You Will Demonstrate

- A three-service platform on **GKE** (Standard or Autopilot), built with layered Terraform
- Private nodes on a VPC-native network, with Cloud NAT for outbound traffic
- **Workload Identity** for pods and **Workload Identity Federation** for GitHub Actions: no service-account keys anywhere
- **Google Managed Prometheus** scraping the apps' existing `/metrics` endpoints
- Availability and latency **SLOs** with fast-burn (page) and slow-burn (ticket) alerts
- GitOps governance (Gatekeeper, Trivy, Checkov), the Slack/ServiceNow/Jira incident pipeline, self-healing scripts, and five chaos drills with recovery-time evidence

## AWS (V9) → Google Cloud (V10)

| Concern | V9 on AWS | V10 on Google Cloud |
|---|---|---|
| Kubernetes | EKS + managed node group | GKE Standard node pool, or Autopilot |
| Images | ECR | Artifact Registry (cleanup policy keeps the last 15) |
| Terraform state | S3 bucket + DynamoDB lock | GCS bucket (versioned, locks built in) |
| Network | VPC, public/private subnets, IGW | Global VPC, regional subnet with pod/service ranges, Cloud NAT |
| Pod permissions | IRSA (IAM roles for service accounts) | Workload Identity (KSA → Google service account) |
| CI/CD identity | GitHub OIDC → IAM role | GitHub OIDC → Workload Identity Federation |
| Metrics | Self-run Prometheus | Google Managed Prometheus (`PodMonitoring`, `Rules`) |
| SLOs | Prometheus alert rules | Cloud Monitoring SLOs + burn-rate alert policies |
| Load balancer | ELB (hostname) | GCP external load balancer (IP) |
| Cost guardrail | AWS Budgets | Cloud Billing budget (50% / 90% / 100%) |

**Unchanged:** `apps/` (except two fixes below), `platform/helm/` (values only), `governance/`, `incident/`, `automation/`, and drills 1, 3, and 4 in `chaos/`.

## Project Structure

```text
express-reliability-platform-v10/
├── apps/                          # flask-api, node-api, web-ui
├── platform/
│   ├── helm/                      # same charts; Workload Identity SA + SHA image tags
│   └── terraform/
│       ├── bootstrap/             # APIs, GCS state, Artifact Registry, CI identity, budget
│       ├── shared/                # VPC, subnet + secondary ranges, Cloud NAT
│       ├── modules/gke/           # GKE cluster, node pool, Workload Identity
│       └── live/                  # calls the module + slo.tf (SLOs and burn-rate alerts)
├── monitoring/gmp/                # PodMonitoring + alert Rules for Managed Prometheus
├── governance/  incident/  automation/
├── chaos/                         # five drills (error_budget_burn.sh is new)
├── scripts/                       # deploy, build/push, cleanup, chaos suite, risk score
└── .github/workflows/deploy.yml   # keyless deploy to GKE
```

## Prerequisites

- A Google Cloud project with billing enabled. New accounts usually get trial credit.
- `gcloud` (with `gke-gcloud-auth-plugin`), `terraform` ≥ 1.5, `kubectl`, `helm`, and `docker` with buildx
- Sign in once:

```sh
gcloud auth login
gcloud auth application-default login
```

## Run It

```sh
cd express-reliability-platform-v10
export PROJECT_ID="your-project-id"
export ALERT_EMAIL="you@example.com"   # optional: where burn-rate alerts go
export AUTOPILOT=false                  # true = GKE Autopilot

./scripts/deploy_capstone.sh
```

The script runs bootstrap → images → shared → live (cluster + SLOs) → Workload Identity → Helm → Gatekeeper → Managed Prometheus.

Then start self-healing in one terminal and run the chaos suite in another:

```sh
INTERVAL=30 ./automation/recovery_policy.sh
./scripts/chaos_suite.sh
```

To test the SLO alert on its own:

```sh
ERROR_RATE=0.2 DURATION=300 ./chaos/error_budget_burn.sh
```

Then open **Cloud Monitoring → Services → erp-flask-api**. You will see the error budget drop and the fast-burn alert fire.

## SLOs

| SLO | Target | Window | Alerts |
|---|---|---|---|
| Availability: requests that do not return 5xx | 99.5% | 28 days | Page at 14.4× burn over 1h; ticket at 6× over 6h |
| Latency: `/score` responses under 500 ms | 95% | 28 days | Warn at 14.4× burn over 1h |

**Why 99.5%?** The 28-day error budget is 0.5%, about 3.4 hours of full outage. That is tight enough to matter for a customer-facing API and loose enough to ship weekly. A 14.4× burn means about 2% of the monthly budget is gone in one hour, so it pages. A 6× burn over 6 hours is a slow leak, so it opens a ticket. This is the multi-window approach from the Google SRE Workbook.

## Keyless CI/CD (optional)

1. Re-run bootstrap with your repo:

   ```sh
   terraform -chdir=platform/terraform/bootstrap apply \
     -var project_id=$PROJECT_ID -var github_repo=<owner>/<repo>
   ```

2. Add four repository secrets from `terraform -chdir=platform/terraform/bootstrap output`:
   - `GCP_PROJECT_ID`
   - `GCP_WORKLOAD_IDENTITY_PROVIDER`
   - `GCP_SERVICE_ACCOUNT`
   - `GCP_STATE_BUCKET`

3. Copy `.github/workflows/deploy.yml` to the repository root's `.github/workflows/`.

The pipeline runs: Trivy + Checkov → Terraform → risk score → build/push (tagged with the commit SHA) → Helm → pod-kill chaos drill.

## Fixes Carried Into V10

- **flask-api** now counts every request with its real status code. V9 only counted successes, so a 5xx SLO could never see a failure. Health checks and scrapes are excluded so they do not inflate the SLO.
- **Images are tagged with the git SHA**, not `:latest`. Gatekeeper's `no-latest-tag` policy would otherwise block replacement pods during chaos drills.
- **node-api** gets `FLASK_BASE_URL` from Helm, so it reaches flask-api through its Service.
- **`risk_score.sh`** reads the load balancer IP, because GKE exposes an IP rather than an AWS-style hostname.

## Cost Control

Run cleanup at the end of every session:

```sh
./scripts/cleanup_capstone.sh
```

- A zonal Standard cluster (the default) or one Autopilot cluster per billing account falls under GKE's free cluster-management tier. You pay for nodes or pods, the load balancer, and NAT while it runs.
- Set `billing_account` in bootstrap to get budget alerts.

## Autopilot Notes

- With `AUTOPILOT=true`, Google manages nodes. The node-drain drill skips itself, and the script skips open-source Gatekeeper (use GKE Policy Controller).
- Managed Prometheus and Workload Identity are on by default.

## Validation Checklist

- [ ] `terraform validate` passes in `bootstrap`, `shared`, and `live`
- [ ] All three services are healthy on GKE and the web UI answers on the load balancer IP
- [ ] Pods run as `platform-workload` with the `iam.gke.io/gcp-service-account` annotation
- [ ] Managed Prometheus shows `flask_api_requests_total` in Metrics Explorer
- [ ] Both SLOs appear under Cloud Monitoring → Services
- [ ] Drill 5 fires the fast-burn alert, then recovers within SLO
- [ ] Chaos suite results and recovery times recorded in `docs/README.md`
- [ ] `cleanup_capstone.sh` leaves no cluster, NAT, or load balancer running

## Results (fill in after your run)

| Drill | Failure injected | Recovery time | SLO | Result |
|---|---|---|---|---|
| 1 | Pod kill (flask-api) | [X]s | 60s | |
| 2 | Node drain (Standard only) | [X]s | 120s | |
| 3 | CPU pressure (HPA) | [X]s | 90s | |
| 4 | Crash loop | [X]s | 60s | |
| 5 | Error-budget burn (20% 5xx) | [X]s | 90s | |

Only publish numbers from your own runs.
