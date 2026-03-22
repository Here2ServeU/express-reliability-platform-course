# Express Reliability Platform V4 — Observability + Real-World Simulation

## Builds on V3

Before you start V4, copy your personal V3 repository to your local machine and rename it to V4:

```sh
git clone https://github.com/YOUR_USERNAME/express-reliability-platform-v03.git
mv express-reliability-platform-v03 express-reliability-platform-v04
cd express-reliability-platform-v04
```

Use the main class repository for scripts and canonical structure:

- https://github.com/Here2ServeU/express-reliability-platform-course

## 1) Version Purpose

Add observability to the platform and practice reliability engineering with controlled stress and failure scenarios.

---

## Plain Language Context

**What is this version teaching you?**
You add a live dashboard to your platform so you can see exactly what is happening inside it at any moment — how fast it is responding, how many errors it is producing, and whether it is healthy. Without this, running a platform is like driving a car with no dashboard: you have no idea how fast you are going or when you are about to run out of fuel.

**How does a bank or hospital use this?**
Banks monitor transaction response times in real time. A sudden spike in latency can indicate fraud traffic, a server overload, or a network failure. A hospital monitoring platform tracks whether patient-record requests are succeeding. When a metric crosses a threshold, engineers get an alert immediately — not an hour later when users start calling.

**Key terms in plain language:**

| Term | What It Means |
|---|---|
| **Prometheus** | A program that collects numbers from your services every few seconds and stores them — like a health monitor taking readings continuously |
| **Metrics** | Numbers that describe how your system is performing — request rate, error rate, response time, memory usage |
| **Grafana** | A tool that draws metrics as charts and dashboards — like turning a spreadsheet of numbers into a visual graph |
| **SLI (Service Level Indicator)** | The actual measured value — for example, the real p95 response time right now |
| **SLO (Service Level Objective)** | The target you promise — for example, "p95 response time must stay under 500ms" |
| **p95 (95th percentile)** | The response time that 95% of requests are faster than — so if p95 is 400ms, 95 out of 100 requests finished in 400ms or less |
| **Alertmanager** | A tool connected to Prometheus that sends notifications when a metric crosses a threshold |
| **Load generation** | Sending many requests to your system to observe how it behaves under real traffic |

**Expected result at the end of this version:**
- `http://localhost:9090` shows Prometheus with your services listed as targets.
- `http://localhost:3001` shows Grafana with a working datasource.
- You can see metric values change in Grafana while generating load.

---


## Training Workflow (Understand -> Build -> Test -> Break -> Fix -> Explain -> Automate -> Improve)

1. Understand: Read monitoring architecture and metric goals.
2. Build: Start the monitored stack and configure dashboards.
3. Test: Confirm targets are up and metrics change under load.
4. Break: Trigger a controlled fault or stress event.
5. Fix: Use metrics, logs, and alerts to recover.
6. Explain: Document what failed, why it failed, and what fixed it.
7. Automate: Add repeatable stress tests and alert checks.
8. Improve: Tune SLI/SLO thresholds and alert quality.

## 3) What You Will Build

- A monitored stack with service metrics in Prometheus.
- Dashboards in Grafana for reliability visibility.
- A repeatable method to test latency/error behavior.

## 3.1) Why Terraform Is Included in V4

Terraform is infrastructure-as-code (IaC): you define infrastructure in versioned files instead of creating it manually in a cloud console.

In V4, Terraform is included as a foundation step so you can:

- Standardize how environments are declared and reproduced.
- Validate cloud credentials and provider configuration early.
- Prepare for V5+, where platform infrastructure (VPC/EKS/modules) is managed through Terraform at scale.

V4 is still primarily a local observability build (Compose + Prometheus + Grafana), but the `terraform/` folder gives you a clean transition path from local reliability testing to cloud provisioning workflows.

## 4) Architecture Diagram (Mermaid)

```mermaid
flowchart LR
    User[Browser] --> UI[Web UI]
    UI --> Node[Node API]
    UI --> Flask[Flask API]
    Node --> MetricsN[/metrics/]
    Flask --> MetricsF[/metrics/]
    Prom[Prometheus] --> MetricsN
    Prom --> MetricsF
    Graf[Grafana] --> Prom
```

## 5) Project Structure

```text
express-reliability-platform-v04/
├── apps/
│   ├── node-api/
│   ├── flask-api/
│   └── web-ui/
├── monitoring/
│   ├── prometheus.yml
│   ├── alert.rules.yml
│   └── grafana-dashboard.json
├── docker-compose.yml
├── terraform/
│   └── main.tf
└── README.md
```

## 6) Run Steps

1. Run the local Docker Compose gate first:

   ```sh
   docker compose up --build
   ```

2. Open endpoints:
   - App UI: `http://localhost:8080`
   - Node API: `http://localhost:3000`
   - Flask API: `http://localhost:5000`
   - Prometheus: `http://localhost:9090`
   - Grafana: `http://localhost:3001`

3. Generate load with any HTTP tool (`hey`, `ab`, or browser refresh loops).
4. Import the starter dashboard in Grafana:
   - Open Grafana (`http://localhost:3001`) and go to **Dashboards -> New -> Import**.
   - Upload `monitoring/grafana-dashboard.json`.
   - Select your Prometheus datasource and complete import.
5. Observe latency, request count, and error trends in Grafana.
6. After local validation passes, promote to cloud in order: `dev -> staging -> prod`.

### How to Use `monitoring/grafana-dashboard.json`

Use this JSON file as a prebuilt dashboard template so you do not have to create panels manually.

1. Start the stack first:

   ```sh
   docker compose up --build
   ```

2. Confirm Prometheus is collecting targets:
   - Open `http://localhost:9090/targets`.
   - Verify `node-api` and `flask-api` are `UP`.

3. Configure Prometheus as a Grafana datasource:
   - Open Grafana at `http://localhost:3001`.
   - Go to **Connections -> Data sources -> Add data source**.
   - Choose **Prometheus**.
   - Set URL to `http://prometheus:9090` (inside Docker network).
   - Click **Save & test**.

4. Import the dashboard JSON:
   - Go to **Dashboards -> New -> Import**.
   - Upload `monitoring/grafana-dashboard.json`.
   - In the import screen, map `DS_PROMETHEUS` to your Prometheus datasource.
   - Click **Import**.

5. Validate the dashboard is working:
   - Open `http://localhost:3000/` and `http://localhost:5000/` several times to generate traffic.
   - In Grafana, confirm panels show non-empty series (availability, Flask request rate, and process memory).

6. If panels are blank, check these first:
   - Time range is too narrow: set dashboard range to `Last 15 minutes`.
   - Datasource mapping issue: re-import and ensure `DS_PROMETHEUS` is mapped correctly.
   - No traffic yet: hit API endpoints again to produce fresh metrics.

## 7) Validation Checklist

- [ ] Compose launches all app and monitoring services.
- [ ] Prometheus targets show app services as `UP`.
- [ ] Grafana can query Prometheus data source.
- [ ] You can observe metric changes while generating load.

## 8) Troubleshooting

- Prometheus target down: verify service name and port in `monitoring/prometheus.yml`.
- Grafana empty dashboards: confirm Prometheus datasource URL.
- Container restart loops: inspect logs with `docker compose logs <service>`.

## 9) Cleanup

```sh
docker compose down
```

- If you provisioned cloud resources for this version, destroy non-shared test resources after validation.

## 10) Next Version Preview

In V5, you build on V4 by moving to Kubernetes on EKS and adding self-healing and autoscaling concepts.

---

## Chapter 14: Basic Monitoring in AWS (Terraform Extension)

### 14.1 What You Are Doing

In this chapter you extend the local observability stack you built (Prometheus + Grafana) into AWS so that the same reliability signals — request errors, CPU load, log output — are also captured at the cloud layer.

You will:
- Route container logs to **CloudWatch Logs** using the ECS `awslogs` driver.
- Register an **ECS Cluster** with Container Insights enabled so per-task CPU and memory metrics are published automatically.
- Create **CloudWatch Metric Alarms** that fire when error counts or CPU utilisation cross reliability thresholds.
- Wire alarms to an **SNS Topic** so notifications reach an email address of your choice.

This prepares you for production-level systems where you need centralised, durable observability that survives container restarts and is queryable by the whole team — not just whoever is running Grafana locally.

**Plain-language analogy:** Prometheus watches your services from inside the house. CloudWatch watches them from the street — and calls you when something goes wrong, even if your laptop is closed.

---

### 14.2 Terraform Concepts Introduced

| Resource | What It Does |
|---|---|
| `aws_cloudwatch_log_group` | Central log destination. Every ECS container sends stdout/stderr here via the `awslogs` Docker log driver. |
| `aws_ecs_cluster` | Logical group that holds your ECS services. `containerInsights = enabled` publishes automatic CPU/memory metrics. |
| `aws_sns_topic` | Notification channel. Alarms publish here; subscribers (email, PagerDuty, Slack) receive them. |
| `aws_sns_topic_subscription` | Wires an email address to the SNS topic; set `var.alarm_email` to activate. |
| `aws_cloudwatch_metric_alarm` | Watches a specific CloudWatch metric and triggers when it crosses a threshold. |

---

### 14.3 Project Structure with Terraform Scripts

```text
express-reliability-platform-v04/
├── apps/
│   ├── node-api/
│   ├── flask-api/
│   └── web-ui/
├── monitoring/
│   ├── prometheus.yml
│   ├── alert.rules.yml
│   └── grafana-dashboard.json
├── docker-compose.yml
├── terraform/
│   └── main.tf          ← Chapter 14 AWS monitoring resources
└── README.md
```

**What `terraform/main.tf` now declares:**

```
terraform/ 
└── main.tf
    ├── provider + version lock
    ├── variables (region, environment, log_retention_days, alarm_email)
    ├── aws_cloudwatch_log_group  — /ecs/express-reliability-platform-<env>
    ├── aws_ecs_cluster           — Container Insights ON
    ├── aws_sns_topic             — alert notification channel
    ├── aws_sns_topic_subscription — optional email subscriber
    ├── aws_cloudwatch_metric_alarm: node_api_high_errors
    ├── aws_cloudwatch_metric_alarm: ecs_high_cpu
    └── outputs (log_group_name, ecs_cluster_name, alerts_topic_arn)
```

---

### 14.4 Run Steps

1. Export AWS credentials:

   ```sh
   export AWS_ACCESS_KEY_ID=your_key
   export AWS_SECRET_ACCESS_KEY=your_secret
   export AWS_DEFAULT_REGION=us-east-1
   ```

2. Initialise Terraform and download the AWS provider:

   ```sh
   cd terraform/
   terraform init
   ```

3. Preview the changes:

   ```sh
   terraform plan -var="environment=dev" -var="alarm_email=you@example.com"
   ```

4. Confirm the plan looks right, then apply:

   ```sh
   terraform apply -var="environment=dev" -var="alarm_email=you@example.com"
   ```

5. Confirm the resources exist in AWS:
   - CloudWatch → Log groups → `/ecs/express-reliability-platform-dev`
   - ECS → Clusters → `express-reliability-platform-dev`
   - CloudWatch → Alarms → `erp-dev-node-api-high-errors` and `erp-dev-ecs-high-cpu`

6. Check your inbox and confirm the SNS subscription email.

7. Destroy after validation:

   ```sh
   terraform destroy -var="environment=dev"
   ```

---

### 14.5 Validation Checklist

- [ ] `terraform init` completes without errors.
- [ ] `terraform plan` shows 6 resources to add (log group, cluster, SNS topic, subscription, 2 alarms).
- [ ] `terraform apply` completes successfully.
- [ ] CloudWatch log group appears in AWS Console.
- [ ] ECS cluster appears with Container Insights enabled.
- [ ] Both CloudWatch alarms are in `OK` or `INSUFFICIENT_DATA` state (not `ALARM`).
- [ ] SNS subscription confirmation email is received.

---

### 14.6 Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| `NoCredentialProviders` | AWS credentials not set | Export `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` |
| `AlreadyExistsException` on cluster | Cluster created previously | Import with `terraform import aws_ecs_cluster.platform <name>` |
| Alarm stuck in `INSUFFICIENT_DATA` | No ECS tasks running yet | Deploy a task to the cluster so metrics flow |
| No SNS confirmation email | `alarm_email` not set or wrong | Re-apply with correct `-var="alarm_email=..."` |
