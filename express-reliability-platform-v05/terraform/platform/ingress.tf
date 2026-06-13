resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository  = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  set { name = "clusterName"; value = var.cluster_name }
  set { name = "serviceAccount.create"; value = "true" }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.alb_controller.arn
  }
  depends_on = [aws_eks_node_group.main]
}
