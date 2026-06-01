output "cluster_name" {
  value       = aws_eks_cluster.main.name
  description = "Name of the EKS cluster: feed this to `aws eks update-kubeconfig`."
}

output "cluster_endpoint" {
  value       = aws_eks_cluster.main.endpoint
  description = "EKS API server endpoint URL."
}

output "cluster_certificate_authority_data" {
  value       = aws_eks_cluster.main.certificate_authority[0].data
  description = "Base64-encoded CA cert for the cluster: needed by kubectl/Helm clients connecting outside the AWS auth flow."
  sensitive   = true
}

output "node_group_name" {
  value       = aws_eks_node_group.workers.node_group_name
  description = "Name of the managed node group."
}
