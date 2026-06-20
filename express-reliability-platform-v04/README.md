# Express Reliability Platform V4: Observability and Terraform for ECS

## Version Purpose

Version 4 adds observability to the platform. Prometheus records service metrics, Grafana displays live
dashboards, Alertmanager evaluates alert rules, and Terraform replaces hand-typed AWS setup.

## Goal

Add `/metrics` to services, start the application plus Prometheus and Grafana, generate traffic, break
one service on purpose, use dashboards to diagnose it, and deploy to AWS using Terraform.

## Project Structure

```text
express-reliability-platform-v04/
├── apps/
│   ├── flask-api/
│   ├── node-api/
│   └── web-ui/
├── monitoring/
│   ├── prometheus.yml
│   ├── alert.rules.yml
│   ├── alertmanager/alertmanager.yml
│   ├── grafana-dashboard.json
│   └── grafana-dashboard-golden-signals.json
├── terraform/
│   ├── bootstrap/
│   └── platform/
├── docker-compose.yml
├── scripts/
│   ├── tf_deploy.sh
│   ├── build_push_images.sh
│   └── cleanup_v4.sh
└── README.md
```

## Prerequisites

Before running this version, confirm:

- [ ] **Node.js 18+**, **Docker Desktop running** (`docker ps`), and **Docker Compose v2** available.
- [ ] **AWS CLI v2 configured** with credentials — verify: `aws sts get-caller-identity`.
- [ ] **Terraform ≥ 1.5** installed (`terraform version`).
- [ ] **Make the helper scripts executable** (one time):
  ```sh
  chmod +x scripts/*.sh
  ```

## Run Steps

Start the local observability stack:

```sh
docker compose up --build -d
docker compose ps
```

Open:

- App UI: `http://localhost:8080`
- Prometheus: `http://localhost:9090`
- Grafana: `http://localhost:3001`
- Alertmanager: `http://localhost:9093`

Deploy to AWS with Terraform:

```sh
./scripts/tf_deploy.sh
```

## Validation Checklist

- [ ] Prometheus targets are UP.
- [ ] Grafana dashboard shows request rate, latency, errors, and service health.
- [ ] Stopping a service causes `ServiceDown` to fire.
- [ ] Terraform bootstrap creates remote state resources.
- [ ] Terraform platform deploy creates ECS/Fargate infrastructure.
