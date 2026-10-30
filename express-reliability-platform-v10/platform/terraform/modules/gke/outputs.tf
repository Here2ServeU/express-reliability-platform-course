output "cluster_name" { value = google_container_cluster.main.name }
output "cluster_location" { value = google_container_cluster.main.location }
output "cluster_endpoint" { value = google_container_cluster.main.endpoint }
output "workload_service_account" { value = google_service_account.workload.email }
