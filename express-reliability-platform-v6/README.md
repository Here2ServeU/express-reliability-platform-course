# Express Reliability Platform V6 (EKS Edition)

## Chapters Covered
- Chapter 18: Advanced Security and Compliance Automation
- Chapter 19: Advanced Cost Optimization and FinOps
- Chapter 20: Helm for Kubernetes Package Management
- Chapter 21: Multi-Service Provisioning (Fintech, Hospital, UI Portal)
- Chapter 22: Accessing and Validating Services Online
- Chapter 23: Adding Security, Compliance, and Monitoring Modules
- Chapter 24: Customizing Services for Business Requirements

## Quick Start (For Beginners)

1. **Sign up for AWS**: Go to [aws.amazon.com](https://aws.amazon.com/) and create a free account.
2. **Install Prerequisites**:
   - Install [Git](https://git-scm.com/downloads)
   - Install [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
   - Install [Helm](https://helm.sh/docs/intro/install/)
   - Install [kubectl](https://kubernetes.io/docs/tasks/tools/)
3. **Clone the Project**:
   ```sh
   git clone <URL-of-this-repo>
   cd express-reliability-platform-course/express-reliability-platform-v6
   ```
4. **Configure Your Environment**:
   - Open `environments/live/live.tfvars` and `environments/shared/shared.tfvars` in a text editor.
   - Make sure your region is set to `us-east-1`.
5. **Deploy the Platform (EKS)**:
   ```sh
   cd environments/live
   terraform init
   terraform plan -out=tfplan
   terraform apply tfplan
   ```
6. **Configure kubectl**:
   - After Terraform finishes, run:
     ```sh
     aws eks --region us-east-1 update-kubeconfig --name <eks-cluster-name>
     ```
   - Test your connection:
     ```sh
     kubectl get nodes
     ```
7. **Deploy Services with Helm**:
   - Install the fintech, hospital, and UI portal charts:
     ```sh
     helm install fintech ./helm/fintech
     helm install hospital ./helm/hospital
     helm install ui-portal ./helm/ui-portal
     ```
8. **Access the UI Portal**:
   - Get the ALB/ELB DNS name from Terraform outputs:
     ```sh
     terraform output
     ```
   - Open the `ui_portal_url` in your browser to access all services.

---

## Troubleshooting Tips
- If you see an error about missing AWS credentials, make sure you have set up your AWS account and configured your credentials.
- If Terraform fails, check for typos in your `.tfvars` files and make sure your internet connection is working.
- If `kubectl` or Helm cannot connect, verify your kubeconfig and EKS cluster status.
- If the UI portal does not load, wait a few minutes and try again. Sometimes AWS takes a little time to set up resources.
- For any error, copy the message and search for it online or ask for help.

## Example Screenshot
![Example UI Portal](https://via.placeholder.com/600x300?text=UI+Portal+Screenshot)

---

## Layer 1: Helm for Kubernetes Package Management
- Use Helm charts to package and deploy fintech, hospital, and UI portal services on EKS.
- Store custom charts in a Helm repository and automate releases with GitHub Actions.

## Layer 2: Advanced Cost Optimization and FinOps
- Use Terraform to configure EKS node groups with spot instances and right-size resources.
- Enable AWS Cost Explorer and Budgets.
- Integrate Infracost to estimate and monitor infrastructure costs.

## Layer 3: Advanced Security and Compliance Automation
- Provision advanced IAM roles and enable encryption for all resources.
- Integrate AWS Config, Security Hub, and GuardDuty for continuous compliance.
- Use Kubernetes RBAC and network policies for cluster security.

## Layer 4: Multi-Service Provisioning
- Define Kubernetes resources for fintech, hospital, and UI portal in Helm charts.
- Use express-reliability-platform naming for all resources.
- Provision services in live and shared environments.

## Layer 5: Accessing and Validating Services Online
- Use Terraform outputs to find ALB/ELB DNS names.
- Access the UI portal in your browser to reach fintech and hospital services.
- Validate service health with `kubectl get pods` and Helm status commands.

## Layer 6: Adding Security, Compliance, and Monitoring Modules
- Extend your platform with additional security, compliance, and monitoring modules as needed.
- Integrate Prometheus and Grafana for monitoring.
- Use AWS and Kubernetes tools for advanced protection and visibility.

## Layer 7: Customizing Services for Business Requirements
- Adapt and customize each service (fintech, hospital, UI portal) for your specific business needs using modular Terraform and Helm configurations.
- Add environment variables, secrets, and custom resource definitions as needed.

---

## How to Provision the Services

### 1. Configure Your Environment
- Edit `environments/live/live.tfvars` and `environments/shared/shared.tfvars` to set your environment name and region.

### 2. Define Service Resources
- In `environments/live/main.tf`, add EKS resources and outputs for:
  - Fintech backend (Kubernetes deployment/service)
  - Hospital backend (Kubernetes deployment/service)
  - UI portal (Kubernetes deployment/service, ALB ingress)
- Use the express-reliability-platform naming pattern for all resources.

### 3. Provision with Terraform
- Initialize and apply Terraform in each environment:
  ```sh
  cd environments/live
  terraform init
  terraform plan -out=tfplan
  terraform apply tfplan
  ```
- Repeat for `environments/shared` if you have shared resources.

### 4. Deploy Services with Helm
- Use Helm to install each service chart:
  ```sh
  helm install fintech ./helm/fintech
  helm install hospital ./helm/hospital
  helm install ui-portal ./helm/ui-portal
  ```

### 5. Access the Portals Online
- After provisioning, find the output values in Terraform (e.g., ALB DNS names):
  ```sh
  terraform output
  ```
- Open the UI portal DNS name in your browser. From the UI, you can access both the fintech and hospital portals securely.
- Each service will have its own endpoint, accessible via the UI portal.

### 6. Validate Service Health
- Check pod status:
  ```sh
  kubectl get pods -A
  ```
- Check Helm release status:
  ```sh
  helm list
  ```

## Example Resource Naming
- Fintech: `express-reliability-platform-fintech-<env>`
- Hospital: `express-reliability-platform-hospital-<env>`
- UI Portal: `express-reliability-platform-ui-<env>`

## Next Steps
- Continue to the next chapters for advanced features and customization.

---


