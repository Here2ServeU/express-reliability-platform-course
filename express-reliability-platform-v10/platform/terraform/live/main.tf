# Live layer: the GKE cluster and the SLOs that judge it.
# Reads network values from the shared layer's state (the "whiteboard").

terraform {
  required_version = ">= 1.5"
  # Bucket is passed at init time: -backend-config="bucket=<state_bucket>"
  backend "gcs" {
    prefix = "live"
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

variable "zone" {
  description = "Zone for a Standard zonal cluster (lowest cost)"
  type        = string
  default     = "us-central1-a"
}

variable "state_bucket" { type = string }

variable "autopilot" {
  description = "Run GKE Autopilot instead of Standard"
  type        = bool
  default     = false
}

variable "alert_email" {
  description = "Email for SLO burn-rate alerts. Leave empty to create alerts without a channel."
  type        = string
  default     = ""
}

data "terraform_remote_state" "shared" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "shared"
  }
}

module "gke" {
  source              = "../modules/gke"
  project_id          = var.project_id
  cluster_name        = "reliability-platform"
  location            = var.autopilot ? var.region : var.zone # Autopilot is always regional
  autopilot           = var.autopilot
  network             = data.terraform_remote_state.shared.outputs.network_name
  subnetwork          = data.terraform_remote_state.shared.outputs.subnet_name
  pods_range_name     = data.terraform_remote_state.shared.outputs.pods_range_name
  services_range_name = data.terraform_remote_state.shared.outputs.services_range_name
  node_count          = 2
  machine_type        = "e2-standard-2"
}

output "cluster_name" { value = module.gke.cluster_name }
output "cluster_location" { value = module.gke.cluster_location }
output "cluster_endpoint" { value = module.gke.cluster_endpoint }
output "workload_service_account" { value = module.gke.workload_service_account }
