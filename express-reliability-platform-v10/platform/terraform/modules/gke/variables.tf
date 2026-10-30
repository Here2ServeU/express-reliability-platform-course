variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "cluster_name" {
  description = "Name for the GKE cluster"
  type        = string
}

variable "location" {
  description = "Zone (Standard, cheapest) or region (Autopilot / regional HA)"
  type        = string
}

variable "network" {
  description = "VPC name from the shared layer"
  type        = string
}

variable "subnetwork" {
  description = "Subnet name from the shared layer"
  type        = string
}

variable "pods_range_name" {
  description = "Secondary range for pod IPs"
  type        = string
}

variable "services_range_name" {
  description = "Secondary range for Service IPs"
  type        = string
}

variable "autopilot" {
  description = "true = GKE Autopilot (Google manages nodes, pay per pod). false = Standard (you manage the node pool; needed for the node-drain chaos drill)."
  type        = bool
  default     = false
}

variable "node_count" {
  description = "Starting node count for Standard mode"
  type        = number
  default     = 2
}

variable "machine_type" {
  description = "Machine type for Standard mode nodes"
  type        = string
  default     = "e2-standard-2"
}

variable "release_channel" {
  description = "GKE release channel: RAPID, REGULAR, or STABLE"
  type        = string
  default     = "REGULAR"
}

variable "app_namespace" {
  description = "Kubernetes namespace the apps run in"
  type        = string
  default     = "platform"
}

variable "app_ksa" {
  description = "Kubernetes service account the apps run as"
  type        = string
  default     = "platform-workload"
}
