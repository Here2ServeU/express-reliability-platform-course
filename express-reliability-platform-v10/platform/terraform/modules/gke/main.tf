# GKE module. Replaces the V9 EKS module.
#
# EKS -> GKE mapping:
#   aws_eks_cluster              -> google_container_cluster
#   aws_eks_node_group           -> google_container_node_pool (Standard only)
#   cluster/node IAM roles       -> a least-privilege node service account
#   IRSA (IAM roles for pods)    -> Workload Identity (KSA -> Google SA, no keys)
#   CloudWatch Container Insights-> Cloud Logging/Monitoring + Managed Prometheus

locals {
  workload_pool = "${var.project_id}.svc.id.goog"
}

# ── Node identity (Standard mode). Never use the default compute SA. ──────
resource "google_service_account" "nodes" {
  count        = var.autopilot ? 0 : 1
  account_id   = "erp-gke-nodes"
  display_name = "GKE nodes for ${var.cluster_name}"
}

resource "google_project_iam_member" "nodes" {
  for_each = var.autopilot ? toset([]) : toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/artifactregistry.reader",
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.nodes[0].email}"
}

# ── The cluster. Google runs the control plane. ───────────────────────────
resource "google_container_cluster" "main" {
  name     = var.cluster_name
  location = var.location

  enable_autopilot = var.autopilot ? true : null

  # Standard mode: drop the default pool and manage our own below.
  remove_default_node_pool = var.autopilot ? null : true
  initial_node_count       = var.autopilot ? null : 1

  network         = var.network
  subnetwork      = var.subnetwork
  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # Private nodes, public control-plane endpoint (protected by IAM).
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  release_channel { channel = var.release_channel }

  # Autopilot always enables Workload Identity; Standard needs it set.
  dynamic "workload_identity_config" {
    for_each = var.autopilot ? [] : [1]
    content { workload_pool = local.workload_pool }
  }

  # Standard: turn on workload logs and Managed Prometheus explicitly.
  # Autopilot: both are on by default and managed by Google.
  dynamic "logging_config" {
    for_each = var.autopilot ? [] : [1]
    content { enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"] }
  }

  dynamic "monitoring_config" {
    for_each = var.autopilot ? [] : [1]
    content {
      enable_components = ["SYSTEM_COMPONENTS"]
      managed_prometheus { enabled = true } # scrapes /metrics via PodMonitoring
    }
  }

  # Lab-friendly: lets `terraform destroy` remove the cluster.
  deletion_protection = false
}

resource "google_container_node_pool" "main" {
  count    = var.autopilot ? 0 : 1
  name     = "${var.cluster_name}-pool"
  cluster  = google_container_cluster.main.id
  location = var.location

  initial_node_count = var.node_count
  autoscaling {
    min_node_count = 1
    max_node_count = var.node_count + 2
  }

  # Google patches and replaces unhealthy nodes automatically.
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = var.machine_type
    disk_size_gb    = 50
    service_account = google_service_account.nodes[0].email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    labels          = { team = "platform" }

    workload_metadata_config { mode = "GKE_METADATA" } # required for Workload Identity

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  depends_on = [google_project_iam_member.nodes]
}

# ── Workload Identity for the apps: pods get Google credentials, no keys ──
resource "google_service_account" "workload" {
  account_id   = "erp-workload"
  display_name = "App workloads on ${var.cluster_name}"
}

resource "google_project_iam_member" "workload" {
  for_each = toset([
    "roles/monitoring.metricWriter",
    "roles/cloudtrace.agent",
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.workload.email}"
}

# Allow the Kubernetes SA platform/platform-workload to act as the Google SA.
resource "google_service_account_iam_member" "workload_binding" {
  service_account_id = google_service_account.workload.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${local.workload_pool}[${var.app_namespace}/${var.app_ksa}]"
  depends_on         = [google_container_cluster.main]
}
