resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.7.2" # ships controller v2.7.2 — matches the IAM policy in iam.tf
  namespace  = "kube-system"
  set {
    name  = "clusterName"
    value = var.cluster_name
  }
  # Pass region and VPC ID explicitly so the controller does not try to read them
  # from EC2 instance metadata (the node IMDS hop limit blocks pods -> 401 crash).
  set {
    name  = "region"
    value = var.region
  }
  set {
    name  = "vpcId"
    value = aws_vpc.main.id
  }
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.alb_controller.arn
  }
  depends_on = [aws_eks_node_group.main]
}
