# Express Reliability Platform Course

This repository is the implementation track for the **IT Career Acceleration Playbook**. You build one reliability platform in 10 versions, from local development to cloud operations, AIOps, cyber-physical systems, and quantum-augmented optimization.

## Course Map (Book Chapters → Platform Versions)

| Version Folder | Book Coverage | Focus |
|---|---|---|
| `express-reliability-platform-v01` | Chapters 1–3 | Local foundation |
| `express-reliability-platform-v02` | Chapters 4–5 | Containerized, portable platform |
| `express-reliability-platform-v03` | Chapters 6–8 | Compose gate + Terraform foundations + IAM/OIDC + ECS/ALB |
| `express-reliability-platform-v04` | Chapters 9–10 | Observability + stress/failure simulation |
| `express-reliability-platform-v05` | Chapters 11–12 | EKS foundations + self-healing/autoscaling |
| `express-reliability-platform-v06` | Chapter 13 | Advanced Terraform discipline and multi-environment promotion |
| `express-reliability-platform-v07` | Chapters 14–15 | Runbooks + incident response + chaos engineering |
| `express-reliability-platform-v08` | Chapter 16 | AIOps for incident management |
| `express-reliability-platform-v09` | Chapter 16 | Cyber-physical reliability workflows |
| `express-reliability-platform-v10` | Post-book labs / bonus extension | Quantum-augmented optimization + robotics integration |
| `express-reliability-platform-capstone` | Final integrated reference | Golden platform for interviews and client delivery |

## How to Use This Repo

1. Start at `express-reliability-platform-v01`.
2. Complete each version README in order.
3. Do not skip versions; each one assumes the previous version is complete.
4. In every version, pass the local Docker Compose test gate first.
5. Then promote to cloud in order: `dev -> staging -> prod`.
6. Use the validation checklist in each README before advancing.

## Scripts and Canonical Structure

Use this main course repository as your source of truth for scripts and project structure:

- https://github.com/Here2ServeU/express-reliability-platform-course

If a script or folder is missing in your personal repository, copy it from the matching version in this course repository.

## Version Upgrade Workflow (Personal GitHub -> Local)

For each new version, start from your previous version repository, clone it locally, and rename it to the next version:

```sh
git clone https://github.com/YOUR_USERNAME/express-reliability-platform-v0X.git
mv express-reliability-platform-v0X express-reliability-platform-v0Y
cd express-reliability-platform-v0Y
```

Then pull in the matching files from the class repository version `v0Y` so your structure stays aligned.

## Version 7 Operations Artifacts

Version 7 includes concrete incident-response artifacts in these paths:

- `express-reliability-platform-v07/artifacts/runbooks/incident-sev1-api-latency.md`
- `express-reliability-platform-v07/artifacts/sre/slo-sli-catalog.md`
- `express-reliability-platform-v07/artifacts/sre/oncall-rotation.md`
- `express-reliability-platform-v07/artifacts/compliance/dr-basics.md`

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

Rev. Dr. Emmanuel developped this curriculum drawing from his experience working for top leading companies and his PhD Research in Computer Science focusing on AI, Machine Learning, Robotics and Quantum Computing applied to Cloud Infra in regulated environments such as Hospitals and FinTech. 

Students in my live classes can use this program at no cost as part of course participation.

## License

This repository is licensed under the terms in [LICENSE](LICENSE).

## Version Guides

Open the README inside each version folder for step-by-step instructions.

After completing V1–V10, use the capstone package in [express-reliability-platform-capstone](express-reliability-platform-capstone/README.md) as the final golden reference platform.
