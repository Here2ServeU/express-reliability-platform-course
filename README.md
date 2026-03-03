# Express Reliability Platform Course

This repository is the implementation track for the **IT Career Acceleration Playbook**. You build one reliability platform in 10 versions, from local development to cloud operations, AIOps, cyber-physical systems, and quantum-augmented optimization.

## Course Map (Book Chapters → Platform Versions)

| Version Folder | Book Coverage | Focus |
|---|---|---|
| `express-reliability-platform-v01` | Chapters 1–3 | Local foundation |
| `express-reliability-platform-v02` | Chapters 4–5 | Containerized, portable platform |
| `express-reliability-platform-v03` | Chapters 6–8 | Compose orchestration + IAM/OIDC + ECS/ALB |
| `express-reliability-platform-v04` | Chapters 9–10 | Observability + stress/failure simulation |
| `express-reliability-platform-v05` | Chapters 11–12 | EKS foundations + self-healing/autoscaling |
| `express-reliability-platform-v06` | Chapter 13 | Terraform and infrastructure-as-code discipline |
| `express-reliability-platform-v07` | Chapter 14 | Runbooks, incident response, DR mindset |
| `express-reliability-platform-v08` | Chapter 15 | AIOps and intelligent infrastructure |
| `express-reliability-platform-v09` | Chapter 16 | Cyber-physical reliability workflows |
| `express-reliability-platform-v10` | Post-book labs / bonus extension | Quantum-augmented optimization + robotics integration |
| `express-reliability-platform-capstone` | Final integrated reference | Golden platform for interviews and client delivery |

## How to Use This Repo

1. Start at `express-reliability-platform-v01`.
2. Complete each version README in order.
3. Do not skip versions; each one assumes the previous version is complete.
4. Use the validation checklist in each README before advancing.

## Recommended Program Layout (for portfolio and class delivery)

```text
b2m-projects/
	express-reliability-platform-v1/
	express-reliability-platform-v2/
	...
	express-reliability-platform-v10/
```

Resource naming convention used across scripts and cloud resources:

- `express-platform-node-api`
- `express-platform-flask-api`
- `express-platform-web-ui`
- `express-platform-ecr-*`
- `express-platform-ecs-*`
- `express-platform-eks-*`

## About the Author

This playbook is based on enterprise delivery experience (including Comcast, Octo, IBM, and related consulting environments) and advanced research in resilient systems.

Students in my live classes can use this program at no cost as part of course participation.

## License

This repository is licensed under the terms in [LICENSE](LICENSE).

## Version Guides

Open the README inside each version folder for step-by-step instructions.

After completing V1–V10, use the capstone package in [express-reliability-platform-capstone](express-reliability-platform-capstone/README.md) as the final golden reference platform.
