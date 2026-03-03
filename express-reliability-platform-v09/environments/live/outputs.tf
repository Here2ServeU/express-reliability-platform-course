output "ui_portal_url" {
  value       = module.alb_ingress.dns_name
  description = "URL to access the UI portal for fintech and hospital services."
}

output "eks_cluster_name" {
  value       = module.eks.cluster_name
  description = "EKS cluster name for kubectl and Helm deployments."
}

output "eks_cluster_endpoint" {
  value       = module.eks.cluster_endpoint
  description = "EKS cluster API endpoint."
}

output "eks_cluster_version" {
  value       = module.eks.cluster_version
  description = "EKS cluster Kubernetes version."
}

output "environment_name" {
  description = "The name of the live environment"
  value       = var.environment_name
}

output "region" {
  description = "The AWS region used for live environment"
  value       = var.region
}

# Add more outputs as needed for Helm chart values, node group details, etc.
