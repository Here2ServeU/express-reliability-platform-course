# Express Reliability Platform V3 - Your First AWS Deployment

## 1) Version Purpose

In Version 2, the platform ran on your laptop. In Version 3, you deploy the same three-service platform to AWS manually so you understand every moving part before Version 4 automates the flow.

By the end of V3, you will:

- Configure the AWS CLI.
- Create ECR repositories.
- Build, tag, and push Docker images for `linux/amd64` (Fargate's default).
- Provision a **dedicated VPC** with public subnets, an Internet Gateway, and a route table.
- Create an IAM task execution role.
- Pre-create CloudWatch log groups.
- Create an ECS cluster, task definitions, and Fargate services.
- Find public task IP addresses.
- Validate the platform from the terminal and a web browser.
- Clean up every cloud resource created by this version, including the VPC.

## 2) What's New in V3 (Latest Updates)

| Update | Why |
|---|---|
| Dedicated VPC (`reliability-platform-v03-vpc`, CIDR `10.42.0.0/16`) | Some AWS accounts have no default VPC; building our own removes that dependency. |
| Public subnets across up to 3 AZs | Spread tasks across availability zones for redundancy. |
| Pre-created CloudWatch log groups | `AmazonECSTaskExecutionRolePolicy` doesn't grant `logs:CreateLogGroup`, so `awslogs-create-group=true` would fail at task startup. |
| `docker build --platform linux/amd64` | Fargate runs `linux/amd64`; without this flag, Apple Silicon Macs produce arm64 images that Fargate can't pull. |
| Idempotent deploy + cleanup scripts | Re-running either script is safe — existing resources are reused or skipped. |
| `--force-new-deployment` on service updates | Bumps services onto the latest task definition revision automatically. |
| IAM-role propagation wait | New roles take ~10s to be usable; the script waits before registering task definitions. |

## 3) Key AWS Terms

| Term | Plain Language Meaning |
|---|---|
| AWS | Amazon Web Services, the cloud provider used in this version. |
| Region | A geographic cluster of AWS data centers. V3 uses `us-east-1`. |
| IAM | Identity and Access Management. Who can do what in AWS. |
| ECR | Elastic Container Registry. Private Docker image storage in AWS. |
| ECS | Elastic Container Service. Runs Docker containers in AWS. |
| Fargate | ECS mode where AWS manages the underlying servers. |
| Task Definition | Blueprint for one container: image, CPU, memory, ports, logs. |
| Service | Keeps the requested number of tasks running. |
| Cluster | Logical namespace for ECS services. |
| Security Group | Cloud firewall controlling inbound and outbound traffic. |
| VPC | Your isolated AWS network. V3 creates a dedicated one. |
| Subnet | A range of IP addresses inside a VPC, scoped to one Availability Zone. |
| Internet Gateway (IGW) | The component that lets a VPC route traffic to/from the internet. |
| Route Table | Rules that direct subnet traffic (e.g., `0.0.0.0/0 → IGW`). |
| ENI | Elastic Network Interface. Fargate attaches one per task. |
| Public IP | Internet-reachable address assigned to a Fargate task. |
| CloudWatch Logs | AWS log storage for container output. |
| Task Execution Role | IAM role ECS uses to pull images and write logs. |

## 4) Cost Reminder

ECS Fargate tasks cost money while running. In this version you run three tasks, which is a small hourly cost during practice, but leaving them running for days can become real money. Run `./scripts/cleanup_v3.sh` after every practice session.

## 5) Project Structure

```text
express-reliability-platform-v03/
├── apps/
│   ├── flask-api/
│   ├── node-api/
│   └── web-ui/
├── docker-compose.yml
├── scripts/
│   ├── create_ecr_repos.sh
│   ├── build_tag_push_ecr.sh
│   ├── deploy_ecs.sh
│   ├── get_public_ips.sh
│   └── cleanup_v3.sh
└── README.md
```

## 6) Setup

Install the AWS CLI, then configure credentials:

```sh
aws configure
```

Use:

- Default region name: `us-east-1`
- Default output format: `json`

Validate authentication:

```sh
aws sts get-caller-identity
```

Expected: JSON containing `UserId`, `Account`, and `Arn`.

## 7) Local Test Gate

Before deploying to AWS, confirm the platform still works locally:

```sh
docker compose up --build
```

Endpoints:

- Node API: `http://localhost:3000`
- Flask API: `http://localhost:5000`
- Web UI: `http://localhost:8080`

Stop the stack:

```sh
docker compose down
```

## 8) AWS Deployment Steps

Run from the `express-reliability-platform-v03` directory.

**1. Create the ECR repositories:**

```sh
./scripts/create_ecr_repos.sh
```

**2. Build, tag, and push all three images** (forces `linux/amd64` for Fargate):

```sh
./scripts/build_tag_push_ecr.sh
```

> On Apple Silicon, builds go through QEMU emulation and take noticeably longer than native arm64 builds — this is expected.

**3. Provision VPC, IAM, log groups, ECS cluster, task definitions, and Fargate services:**

```sh
./scripts/deploy_ecs.sh
```

The script is idempotent and prints each step's progress. It will:

1. Ensure the ECS service-linked role exists.
2. Create or reuse VPC `reliability-platform-v03-vpc` (`10.42.0.0/16`).
3. Create or reuse the Internet Gateway.
4. Create or reuse one public subnet per AZ (up to three: `10.42.1.0/24`, `10.42.2.0/24`, `10.42.3.0/24`).
5. Create or reuse a route table with `0.0.0.0/0 → IGW`, associated with all subnets.
6. Create or reuse the ECS cluster.
7. Create or reuse the security group (opens `80`, `3000`, `5000`).
8. Create or reuse the IAM task execution role.
9. Wait for IAM propagation.
10. Pre-create CloudWatch log groups (`/ecs/v03/flask-api`, `/ecs/v03/node-api`, `/ecs/v03/web-ui`).
11. Register task definitions and create or update services with `--force-new-deployment`.
12. Print a summary table of services.

**4. Wait about 90 seconds, then fetch the public IPs:**

```sh
./scripts/get_public_ips.sh
```

## 9) Validate from the Terminal

**Service health (does AWS think the platform is up?):**

```sh
aws ecs describe-services \
  --cluster reliability-platform-v03 \
  --services flask-api node-api web-ui \
  --region us-east-1 \
  --query 'services[].{name:serviceName,desired:desiredCount,running:runningCount,pending:pendingCount,status:status}' \
  --output table
```

You want `running == desired == 1` and `status == ACTIVE` for all three.

**Resolve all three public IPs at once:**

```sh
for SVC in flask-api node-api web-ui; do
  TASK=$(aws ecs list-tasks --cluster reliability-platform-v03 \
    --service-name $SVC --region us-east-1 \
    --query 'taskArns[0]' --output text)
  ENI=$(aws ecs describe-tasks --cluster reliability-platform-v03 \
    --tasks $TASK --region us-east-1 \
    --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
    --output text)
  IP=$(aws ec2 describe-network-interfaces --network-interface-ids $ENI \
    --region us-east-1 \
    --query 'NetworkInterfaces[0].Association.PublicIp' --output text)
  case $SVC in
    web-ui)    echo "$SVC:    http://$IP/" ;;
    flask-api) echo "$SVC: http://$IP:5000/" ;;
    node-api)  echo "$SVC:  http://$IP:3000/" ;;
  esac
done
```

**Reachability test (HTTP 2xx == healthy):**

```sh
curl -sfv http://<web-ui-ip>/
curl -sfv http://<flask-api-ip>:5000/
curl -sfv http://<node-api-ip>:3000/
```

**Live application logs:**

```sh
aws logs tail /ecs/v03/flask-api --since 5m --region us-east-1 --follow
aws logs tail /ecs/v03/node-api  --since 5m --region us-east-1 --follow
aws logs tail /ecs/v03/web-ui    --since 5m --region us-east-1 --follow
```

After hitting an endpoint with curl or a browser, request lines should appear in the log stream.

**Architecture sanity check** (confirms the amd64 fix worked):

```sh
aws ecs describe-tasks --cluster reliability-platform-v03 \
  --tasks $(aws ecs list-tasks --cluster reliability-platform-v03 \
    --service-name flask-api --region us-east-1 \
    --query 'taskArns[0]' --output text) \
  --region us-east-1 \
  --query 'tasks[0].{lastStatus:lastStatus,health:healthStatus}'
```

`lastStatus: RUNNING` means the image was pulled and the container started successfully.

## 10) Validate from the Browser

The script in the previous section prints clickable URLs. Open them in any browser:

| Service | URL pattern | What to expect |
|---|---|---|
| **web-ui** | `http://<web-ui-ip>/` | Rendered HTML page (the user-facing site). |
| **flask-api** | `http://<flask-api-ip>:5000/` | JSON response from the root route. |
| **node-api** | `http://<node-api-ip>:3000/` | JSON response from the root route. |

Common endpoints worth trying:

- `http://<flask-api-ip>:5000/health`
- `http://<node-api-ip>:3000/health`

> Public IPs are **ephemeral**. Every time ECS replaces a task (deploy, crash, manual stop), the new task gets a new public IP. For stable URLs, you would put an Application Load Balancer in front of the services — that's the kind of thing V4+ adds.

### What to do if a page doesn't load

| Symptom | Likely cause | Fix |
|---|---|---|
| Site can't be reached / timeout | Security group blocking, or task not running yet | Re-check service health; wait 60-90s after deploy |
| Connection refused | App is binding to `127.0.0.1` instead of `0.0.0.0` inside the container | Update the app's listen address |
| Page loads but missing data | Cross-service call failing inside the VPC | Check CloudWatch logs on the calling service |
| 4xx/5xx | Application-level error | Check CloudWatch logs |

## 11) Validation Checklist

- [ ] `aws sts get-caller-identity` returns your AWS account.
- [ ] VPC `reliability-platform-v03-vpc` exists and has 2-3 public subnets associated with a route table that routes `0.0.0.0/0` to the IGW.
- [ ] ECR repos exist for `reliability-platform/flask-api`, `reliability-platform/node-api`, and `reliability-platform/web-ui`, each with a `latest` tag built for `linux/amd64`.
- [ ] CloudWatch log groups `/ecs/v03/flask-api`, `/ecs/v03/node-api`, `/ecs/v03/web-ui` exist.
- [ ] ECS cluster `reliability-platform-v03` is `ACTIVE`.
- [ ] Services `flask-api`, `node-api`, and `web-ui` each show `running=1` and `desired=1`.
- [ ] `curl -sf http://<web-ui-ip>/` returns 2xx.
- [ ] Opening the web-ui URL in a browser renders the platform HTML.
- [ ] CloudWatch logs show request lines after you hit an endpoint.

## 12) Troubleshooting

**Task fails to start with `CannotPullContainerError: image Manifest does not contain descriptor matching platform 'linux/amd64'`:**

You're on Apple Silicon and built without `--platform linux/amd64`. Re-run `./scripts/build_tag_push_ecr.sh` (it now passes the flag), then force a redeploy:

```sh
for SVC in flask-api node-api web-ui; do
  aws ecs update-service --cluster reliability-platform-v03 \
    --service $SVC --force-new-deployment --region us-east-1 > /dev/null
done
```

**Task fails to start with `AccessDeniedException: logs:CreateLogGroup`:**

This means a log group is missing. Pre-create them:

```sh
for SVC in flask-api node-api web-ui; do
  aws logs create-log-group --log-group-name "/ecs/v03/$SVC" --region us-east-1 2>/dev/null || true
done
```

Then bounce the services with `--force-new-deployment`.

**`ServiceSchedulerInitiated` stop code:**

Not an error — this is the scheduler stopping an old task as part of a normal deployment cycle. Check `runningCount` on the service; if it's `1`, the new task is healthy.

**Service stuck at `running=0, pending=1`:**

```sh
aws ecs describe-services \
  --cluster reliability-platform-v03 --services flask-api \
  --region us-east-1 \
  --query 'services[0].events[0:5]'
```

The most recent event message tells you why. Common causes: image pull failure, log group missing, subnet has no public IP route.

**Cannot pull image (image exists in ECR but pull fails):**

```sh
aws ecr list-images --repository-name reliability-platform/flask-api --region us-east-1
aws iam list-attached-role-policies --role-name ecsExecRole-v03
```

The execution role must have `AmazonECSTaskExecutionRolePolicy` attached.

**Access denied on AWS calls:**

```sh
aws configure list
aws sts get-caller-identity
```

**Browser shows blank page or won't connect:**

- Confirm the task is `RUNNING`, not just `PENDING`.
- Confirm the security group has inbound rules for `80`, `3000`, and `5000`.
- Confirm the task's subnet has `map-public-ip-on-launch=true` (the deploy script sets this).
- Check CloudWatch log groups under `/ecs/v03/<service-name>` for application errors.

## 13) Cleanup

Run cleanup immediately after each practice session:

```sh
./scripts/cleanup_v3.sh
```

The cleanup script tears down (in dependency order):

1. Scales services to zero.
2. Deletes ECS services.
3. Deletes the ECS cluster.
4. Deletes CloudWatch log groups (`/ecs/v03/*`).
5. Deletes ECR repositories and all images.
6. Detaches and deletes the IAM task execution role.
7. Waits for Fargate ENIs to drain.
8. Deletes the security group.
9. Disassociates and deletes route tables.
10. Deletes subnets.
11. Detaches and deletes the Internet Gateway.
12. Deletes the VPC.
13. Prunes local Docker resources.

After cleanup, verify nothing was left behind:

```sh
aws ecs list-clusters --region us-east-1
aws ec2 describe-vpcs --filters Name=tag:Name,Values=reliability-platform-v03-vpc \
  --query 'Vpcs[].VpcId' --output text --region us-east-1
aws ecr describe-repositories --region us-east-1 \
  --query 'repositories[?starts_with(repositoryName, `reliability-platform/`)].repositoryName'
```

All three commands should return empty / no matches.

## 14) Next Version Preview

Version 4 replaces the manual AWS commands with Terraform, so deployment and cleanup become repeatable infrastructure-as-code workflows.

---

## 15) Web UI Guide — `apps/web-ui/index.html`

### Platform Continuity

The V3 UI keeps the same V2 regulated readiness console and evolves it with cloud promotion checks. Students should experience this as the same platform growing, not as a separate app.

### What the V3 UI Does

The V3 `index.html` is the cloud promotion readiness console. It shows how the V2 platform starts becoming suitable for regulated cloud environments by checking:

- Reliability of the promotion path from local work to cloud environments.
- Cost awareness for dev, staging, and production targets.
- Security maturity through IAM, OIDC, and avoidance of long-lived static keys.
- Intelligence maturity through early telemetry and deployment signals.

### What It Is Used For

Use the V3 UI when explaining whether a bank or hospital workload is ready to move from local development into cloud-hosted environments. Students can use it during demos to show that regulated delivery is not only about "does the app run?" but also "can we prove identity, environment separation, and release evidence?"

The UI is useful for:

- Practicing release gate conversations.
- Explaining dev, staging, and prod readiness.
- Connecting cloud deployment work to regulated audit expectations.
- Showing how V3 prepares the platform for V4 observability.

### How to Read the Results

The UI generates a JSON scorecard with four domain scores and a readiness band.

| Field | Meaning |
|---|---|
| `version` | Confirms this is the V3 cloud promotion assessment. |
| `platform` | The workload or application being evaluated. |
| `environment` | The selected target environment: `dev`, `staging`, or `prod`. |
| `readiness_score` | Overall score from 0 to 100. |
| `readiness_band` | Plain-language result such as `controlled pilot` or `production ready`. |
| `domains.security_compliance` | Strongly affected by identity maturity and release evidence. |
| `next` | The next capability students should build in V4. |

Read the result this way:

- A high score means the platform has a credible cloud promotion story.
- A lower security score usually means IAM, OIDC, or release evidence needs attention.
- A lower reliability score usually means the environment gate is not ready for regulated workloads.
