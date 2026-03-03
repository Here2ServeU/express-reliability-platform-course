# Express Reliability Platform V3 — Orchestration & Identity Foundations

## Chapters Covered
- Chapter 6: From Local Coordination to Cloud Identity Foundations
- Chapter 7: Cloud Orchestration with Amazon ECS (Including Load Balancer)
- Chapter 8: From Manual Deployment to Automated Delivery

## Overview
Version 3 builds on Version 2 by introducing orchestration and identity. You will learn to coordinate multiple services locally with Docker Compose, set up AWS IAM and OIDC for secure cloud access, deploy to ECS with load balancing, and automate delivery with CI/CD pipelines.

---

## Part 1: Manual Provisioning & Deployment

### Local Orchestration
- Use Docker Compose to run Node API, Flask API, and Web UI together:
  ```sh
  docker-compose up --build
  ```
- Access services:
  - Node API: [http://localhost:3000](http://localhost:3000)
  - Flask API: [http://localhost:5000](http://localhost:5000)
  - Web UI: [http://localhost:8080](http://localhost:8080)
- Stop services:
  ```sh
  docker-compose down
  ```

### Cloud Identity Setup (IAM & OIDC)
1. **Create AWS Account**: [https://aws.amazon.com](https://aws.amazon.com)
2. **Enable MFA on root account** and store credentials securely
3. **Create IAM Group** (e.g., `b2m-cloud-engineers`)
   - Attach managed policies for sandbox or least privilege (see chapters)
4. **Create IAM User** (e.g., `b2m-deployer`)
   - Enable programmatic access
   - Add to IAM group
   - Download credentials
5. **Install AWS CLI**: [https://aws.amazon.com/cli/](https://aws.amazon.com/cli/)
   - Configure with `aws configure`
6. **Set Up OIDC for CI/CD**
   - IAM > Identity Providers > Add Provider (OpenID Connect)
   - Provider URL: `https://token.actions.githubusercontent.com`
   - Audience: `sts.amazonaws.com`
   - Create IAM Role for GitHub OIDC provider
   - Restrict to your repo: `repo:YOUR_GITHUB_USERNAME/express-reliability-platform-v3:ref:refs/heads/main`
   - Attach policies (Admin for sandbox, least privilege for production)

### Manual ECS Deployment
- Create ECR repositories for each service
- Build, tag, and push Docker images to ECR
- Create ECS cluster and task definitions
- Deploy services using AWS Fargate
- Attach Application Load Balancer (ALB)
- Test public access via ALB DNS

---

## Part 2: Automated Provisioning & Deployment (GitHub Actions)

### CI/CD Automation
- Set up `.github/workflows/deploy.yml` in your repo
- Configure GitHub secrets for AWS credentials and OIDC
- Workflow steps:
  1. Checkout code
  2. Configure AWS credentials (OIDC role assumption)
  3. Login to ECR
  4. Build and push Docker images
  5. Update ECS service for new deployment
- Example workflow:
  ```yaml
  name: Deploy to ECS
  on:
    push:
      branches:
        - main
  jobs:
    deploy:
      runs-on: ubuntu-latest
      steps:
        - name: Checkout code
          uses: actions/checkout@v4
        - name: Configure AWS credentials
          uses: aws-actions/configure-aws-credentials@v4
          with:
            role-to-assume: arn:aws:iam::ACCOUNT_ID:role/b2m-github-actions-role
            aws-region: us-east-1
        # ...build, tag, push, update ECS steps...
  ```
- On every push to main, your platform is built, pushed, and deployed automatically.

---

## What I Learned
- How to orchestrate multiple services locally
- How to set up secure cloud identity and access (IAM & OIDC)
- How to deploy and scale with ECS and ALB
- How to automate delivery with GitHub Actions CI/CD

---

**Next:** In Version 4, you will add observability, monitoring, and stress testing to your platform.
