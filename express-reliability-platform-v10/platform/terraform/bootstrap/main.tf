# Bootstrap layer: everything the other layers need before they can run.
#   - Turns on the Google Cloud APIs the platform uses
#   - GCS bucket for Terraform state (replaces S3 + DynamoDB; GCS locks natively)
#   - Artifact Registry repository for the three images (replaces ECR)
#   - Optional: keyless GitHub Actions access via Workload Identity Federation
#   - Optional: billing budget with alert thresholds (FinOps guardrail)
# This layer keeps its own state locally because it creates the state bucket.

terraform {
  required_version = ">= 1.5"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 6.0" }
  }
}

provider "google" {
  project               = var.project_id
  region                = var.region
  user_project_override = true # needed so the Budgets API bills quota to this project
  billing_project       = var.project_id
}

variable "project_id" {
  description = "Your Google Cloud project ID"
  type        = string
}

variable "region" {
  description = "Region for the registry and state bucket"
  type        = string
  default     = "us-central1"
}

variable "github_repo" {
  description = "owner/repo allowed to deploy from GitHub Actions. Leave empty to skip CI access."
  type        = string
  default     = ""
}

variable "billing_account" {
  description = "Billing account ID (XXXXXX-XXXXXX-XXXXXX). Leave empty to skip the budget."
  type        = string
  default     = ""
}

variable "monthly_budget_usd" {
  description = "Monthly budget that triggers alerts at 50%, 90%, and 100%"
  type        = number
  default     = 50
}

data "google_project" "this" {}

# ── APIs ───────────────────────────────────────────────────────────────────
resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "artifactregistry.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "cloudtrace.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "billingbudgets.googleapis.com",
  ])
  service            = each.value
  disable_on_destroy = false
}

# ── Terraform state ────────────────────────────────────────────────────────
resource "google_storage_bucket" "tfstate" {
  name                        = "${var.project_id}-erp-tfstate"
  location                    = var.region
  force_destroy               = true
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning { enabled = true } # every state change is recoverable

  lifecycle_rule {
    condition { num_newer_versions = 10 }
    action { type = "Delete" }
  }
}

# ── Container images ───────────────────────────────────────────────────────
resource "google_artifact_registry_repository" "images" {
  repository_id = "reliability-platform"
  location      = var.region
  format        = "DOCKER"
  description   = "Images for flask-api, node-api, and web-ui"

  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"
    most_recent_versions { keep_count = 15 }
  }

  depends_on = [google_project_service.apis]
}

# ── Keyless CI/CD: GitHub Actions -> Google Cloud (no JSON keys stored) ───
resource "google_iam_workload_identity_pool" "github" {
  count                     = var.github_repo == "" ? 0 : 1
  workload_identity_pool_id = "github-actions"
  display_name              = "GitHub Actions"
  depends_on                = [google_project_service.apis]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  count                              = var.github_repo == "" ? 0 : 1
  workload_identity_pool_id          = google_iam_workload_identity_pool.github[0].workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }
  # Only this repository can exchange tokens. Everyone else is rejected.
  attribute_condition = "assertion.repository == \"${var.github_repo}\""

  oidc { issuer_uri = "https://token.actions.githubusercontent.com" }
}

resource "google_service_account" "deployer" {
  count        = var.github_repo == "" ? 0 : 1
  account_id   = "erp-deployer"
  display_name = "Express Reliability Platform deployer (GitHub Actions)"
}

# Scoped roles instead of Owner/Editor.
resource "google_project_iam_member" "deployer" {
  for_each = var.github_repo == "" ? toset([]) : toset([
    "roles/container.admin",
    "roles/compute.networkAdmin",
    "roles/artifactregistry.writer",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountUser",
    "roles/resourcemanager.projectIamAdmin",
    "roles/monitoring.editor",
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.deployer[0].email}"
}

resource "google_storage_bucket_iam_member" "deployer_state" {
  count  = var.github_repo == "" ? 0 : 1
  bucket = google_storage_bucket.tfstate.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.deployer[0].email}"
}

resource "google_service_account_iam_member" "github_impersonation" {
  count              = var.github_repo == "" ? 0 : 1
  service_account_id = google_service_account.deployer[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github[0].name}/attribute.repository/${var.github_repo}"
}

# ── FinOps guardrail ───────────────────────────────────────────────────────
resource "google_billing_budget" "platform" {
  count           = var.billing_account == "" ? 0 : 1
  billing_account = var.billing_account
  display_name    = "express-reliability-platform"

  budget_filter {
    projects = ["projects/${data.google_project.this.number}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(var.monthly_budget_usd)
    }
  }

  threshold_rules { threshold_percent = 0.5 }
  threshold_rules { threshold_percent = 0.9 }
  threshold_rules { threshold_percent = 1.0 }

  depends_on = [google_project_service.apis]
}

# ── Outputs the other layers and scripts read ─────────────────────────────
output "project_id" { value = var.project_id }
output "region" { value = var.region }
output "state_bucket" { value = google_storage_bucket.tfstate.name }
output "registry" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.images.repository_id}"
}
output "workload_identity_provider" {
  value = var.github_repo == "" ? "" : google_iam_workload_identity_pool_provider.github[0].name
}
output "deployer_service_account" {
  value = var.github_repo == "" ? "" : google_service_account.deployer[0].email
}
