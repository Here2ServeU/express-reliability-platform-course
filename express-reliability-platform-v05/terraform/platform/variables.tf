variable "region" { default = "us-east-1" }
variable "cluster_name" { default = "reliability-platform-eks" }
variable "node_type" { default = "t3.medium" }
variable "node_min" { default = 2 }
variable "node_max" { default = 6 }
variable "node_desired" { default = 3 }
variable "k8s_version" { default = "1.30" }
