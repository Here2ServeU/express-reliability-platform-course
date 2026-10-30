# Shared layer: the network. Changes rarely, so it lives in its own state.
# AWS equivalent in V9: VPC + public/private subnets + internet gateway.
#
# GCP differences worth knowing:
#   - A VPC is global; subnets are regional.
#   - GKE uses VPC-native (alias IP) networking: pods and services get their
#     own secondary ranges on the subnet instead of overlay networking.
#   - Nodes are private (no public IPs). Cloud NAT gives them outbound internet.

terraform {
  required_version = ">= 1.5"
  # Bucket is passed at init time: -backend-config="bucket=<state_bucket>"
  backend "gcs" {
    prefix = "shared"
  }
  required_providers {
    google = { source = "hashicorp/google", version = "~> 6.0" }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" { type = string }

variable "region" {
  type    = string
  default = "us-central1"
}

resource "google_compute_network" "main" {
  name                    = "reliability-platform-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "gke" {
  name                     = "reliability-platform-gke"
  region                   = var.region
  network                  = google_compute_network.main.id
  ip_cidr_range            = "10.10.0.0/20" # nodes
  private_ip_google_access = true           # reach Google APIs without public IPs

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.20.0.0/16"
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.30.0.0/20"
  }

  # VPC flow logs: network evidence for incident investigations
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Outbound internet for private nodes (pull public images, reach Slack/Jira)
resource "google_compute_router" "main" {
  name    = "reliability-platform-router"
  region  = var.region
  network = google_compute_network.main.id
}

resource "google_compute_router_nat" "main" {
  name                               = "reliability-platform-nat"
  router                             = google_compute_router.main.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

output "network_name" { value = google_compute_network.main.name }
output "subnet_name" { value = google_compute_subnetwork.gke.name }
output "pods_range_name" { value = "pods" }
output "services_range_name" { value = "services" }
