output "cluster_role_arn" {
  value       = aws_iam_role.cluster.arn
  description = "ARN of the EKS control-plane role. Pass to the cluster module."
}

output "cluster_role_name" {
  value       = aws_iam_role.cluster.name
  description = "Name of the EKS control-plane role."
}

output "node_role_arn" {
  value       = aws_iam_role.nodes.arn
  description = "ARN of the worker node role. Pass to the cluster module."
}

output "node_role_name" {
  value       = aws_iam_role.nodes.name
  description = "Name of the worker node role."
}

