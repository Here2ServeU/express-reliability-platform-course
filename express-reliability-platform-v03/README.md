# Express Reliability Platform V3 - Your First AWS Deployment

## Version Purpose

In Version 2, the platform ran on your laptop. In Version 3, you deploy the same three-service platform to AWS manually so you understand every moving part before Version 4 automates the flow.

By the end of V3, you will:

- Configure the AWS CLI.
- Create ECR repositories.
- Build, tag, and push Docker images.
- Create an IAM task execution role.
- Create an ECS cluster and Fargate services.
- Find public task IP addresses.
- Validate the platform from the internet.
- Clean up every cloud resource created by this version.

## Key AWS Terms

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
| VPC | Your isolated AWS network. |
| Public IP | Internet-reachable address assigned to a Fargate task. |
| CloudWatch Logs | AWS log storage for container output. |
| Task Execution Role | IAM role ECS uses to pull images and write logs. |

## Cost Reminder

ECS Fargate tasks cost money while running. In this version you run three tasks, which is a small hourly cost during practice, but leaving them running for days can become real money. Run `./scripts/cleanup_v3.sh` after every practice session.

## Project Structure

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

## Setup

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

## Local Test Gate

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

## AWS Deployment Steps

Run from the `express-reliability-platform-v03` directory.

Create the ECR repositories:

```sh
./scripts/create_ecr_repos.sh
```

Build, tag, and push all three images:

```sh
./scripts/build_tag_push_ecr.sh
```

Create IAM, networking, ECS task definitions, and Fargate services:

```sh
./scripts/deploy_ecs.sh
```

Wait about 90 seconds, then find public task IPs:

```sh
./scripts/get_public_ips.sh
```

Open the web UI public IP in a browser:

```text
http://WEB_UI_IP
```

## Validation Checklist

- [ ] `aws sts get-caller-identity` returns your AWS account.
- [ ] ECR repos exist for `reliability-platform/flask-api`, `reliability-platform/node-api`, and `reliability-platform/web-ui`.
- [ ] Each ECR repo has a `latest` image tag.
- [ ] ECS cluster `reliability-platform-v03` is `ACTIVE`.
- [ ] Services `flask-api`, `node-api`, and `web-ui` each show running `1` and desired `1`.
- [ ] `http://WEB_UI_IP/` returns the reliability platform HTML.

Useful validation commands:

```sh
aws ecr describe-repositories --region us-east-1 --query 'repositories[*].repositoryName'
aws ecr list-images --repository-name reliability-platform/node-api --region us-east-1 --query 'imageIds[*].imageTag'
aws ecs describe-clusters --clusters reliability-platform-v03 --region us-east-1 --query 'clusters[0].status'
aws ecs describe-services --cluster reliability-platform-v03 --services flask-api node-api web-ui --region us-east-1 --query 'services[*].{n:serviceName,r:runningCount,d:desiredCount}'
```

## Troubleshooting

Task not starting:

```sh
aws ecs list-tasks --cluster reliability-platform-v03 --region us-east-1 --desired-status STOPPED
aws ecs describe-services --cluster reliability-platform-v03 --services flask-api --region us-east-1 --query 'services[0].events[:5]'
```

Cannot pull image:

```sh
aws ecr list-images --repository-name reliability-platform/flask-api --region us-east-1
aws iam list-attached-role-policies --role-name ecsExecRole-v03
```

Access denied:

```sh
aws configure list
aws sts get-caller-identity
```

Connection refused or blank page:

- Confirm the task is running.
- Confirm the security group allows inbound ports `80`, `3000`, and `5000`.
- Check CloudWatch log groups under `/ecs/v03/SERVICE_NAME`.

## Cleanup

Run cleanup immediately after each practice session:

```sh
./scripts/cleanup_v3.sh
```

This scales services to zero, deletes ECS services, deletes the ECS cluster, deletes ECR repositories and images, deletes the task execution role, and prunes local Docker resources.

## Next Version Preview

Version 4 replaces the manual AWS commands with Terraform, so deployment and cleanup become repeatable infrastructure-as-code workflows.
