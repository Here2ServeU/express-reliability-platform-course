
#!/bin/bash
# Initialize and apply Terraform, configure EKS, and deploy Helm charts
set -e
DIR=${1:-.}
EKS_CLUSTER_NAME=${2:-eks-cluster}
REGION=${3:-us-east-1}
cd "$DIR"
echo "Initializing Terraform in $DIR..."
terraform init
terraform apply -auto-approve

echo "Configuring kubectl for EKS..."
aws eks --region "$REGION" update-kubeconfig --name "$EKS_CLUSTER_NAME"
kubectl get nodes

echo "Deploying Helm charts..."
helm install fintech ./helm/fintech || helm upgrade fintech ./helm/fintech
helm install hospital ./helm/hospital || helm upgrade hospital ./helm/hospital
helm install ui-portal ./helm/ui-portal || helm upgrade ui-portal ./helm/ui-portal
helm list
