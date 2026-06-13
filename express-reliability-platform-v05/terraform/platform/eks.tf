resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.k8s_version
  role_arn = aws_iam_role.eks_cluster.arn
  vpc_config {
    subnet_ids              = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)
    endpoint_private_access = true
    endpoint_public_access  = true
  }
  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

# Managed node group: EKS creates and patches the worker EC2 instances
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = aws_subnet.private[*].id
  instance_types  = [var.node_type]
  scaling_config {
    desired_size = var.node_desired
    min_size     = var.node_min
    max_size     = var.node_max
  }
  update_config { max_unavailable = 1 }
  depends_on = [aws_iam_role_policy_attachment.eks_worker]
}

# Built-in add-ons: networking, DNS, storage, proxy
resource "aws_eks_addon" "addons" {
  for_each                    = toset(["vpc-cni", "coredns", "kube-proxy", "aws-ebs-csi-driver"])
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = each.key
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [aws_eks_node_group.main]
}
