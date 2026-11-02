# SLOs as code, judged by Cloud Monitoring.
#
# The flask-api already exposes Prometheus metrics. Google Managed Prometheus
# (enabled on the cluster, scraping via monitoring/gmp/podmonitoring.yaml)
# stores them in Cloud Monitoring under prometheus.googleapis.com/...
#
# Two SLOs over a rolling 28 days:
#   1. Availability: 99.5% of requests do not return 5xx
#   2. Latency:      95% of /score requests finish within 500 ms
#
# Alerting follows the multi-window burn-rate pattern from the Google SRE
# Workbook: page on a fast burn, open a ticket on a slow burn.

locals {
  requests_metric = "prometheus.googleapis.com/flask_api_requests_total/counter"
  latency_metric  = "prometheus.googleapis.com/flask_api_request_latency_seconds/histogram"
  prom_resource   = "resource.type=\"prometheus_target\""
}

resource "google_monitoring_custom_service" "flask_api" {
  service_id   = "erp-flask-api"
  display_name = "Express Reliability Platform: flask-api"
}

resource "google_monitoring_slo" "availability" {
  service             = google_monitoring_custom_service.flask_api.service_id
  slo_id              = "availability-99-5"
  display_name        = "99.5% of requests succeed (28d)"
  goal                = 0.995
  rolling_period_days = 28

  request_based_sli {
    good_total_ratio {
      bad_service_filter = join(" AND ", [
        "metric.type=\"${local.requests_metric}\"",
        local.prom_resource,
        "metric.labels.status=monitoring.regex.full_match(\"5..\")",
      ])
      total_service_filter = join(" AND ", [
        "metric.type=\"${local.requests_metric}\"",
        local.prom_resource,
      ])
    }
  }
}

resource "google_monitoring_slo" "latency" {
  service             = google_monitoring_custom_service.flask_api.service_id
  slo_id              = "latency-500ms-p95"
  display_name        = "95% of /score requests under 500 ms (28d)"
  goal                = 0.95
  rolling_period_days = 28

  request_based_sli {
    distribution_cut {
      distribution_filter = join(" AND ", [
        "metric.type=\"${local.latency_metric}\"",
        local.prom_resource,
      ])
      range { max = 0.5 }
    }
  }
}

resource "google_monitoring_notification_channel" "email" {
  count        = var.alert_email == "" ? 0 : 1
  display_name = "Platform on-call email"
  type         = "email"
  labels       = { email_address = var.alert_email }
}

locals {
  channels = var.alert_email == "" ? [] : [google_monitoring_notification_channel.email[0].id]

  # Burn rate = how fast the error budget is being spent vs. the steady pace.
  #   14.4x over 1h  -> 2% of a 28-day budget gone in an hour: page now
  #    6x   over 6h  -> 5% gone in six hours: open a ticket
  burn_windows = {
    fast = { lookback = "3600s", threshold = 14.4, severity = "CRITICAL" }
    slow = { lookback = "21600s", threshold = 6, severity = "WARNING" }
  }
}

resource "google_monitoring_alert_policy" "availability_burn" {
  for_each     = local.burn_windows
  display_name = "flask-api availability: ${each.key} error-budget burn"
  combiner     = "OR"
  severity     = each.value.severity

  conditions {
    display_name = "Burn rate > ${each.value.threshold}x over ${each.value.lookback}"
    condition_threshold {
      filter          = "select_slo_burn_rate(\"${google_monitoring_slo.availability.id}\", \"${each.value.lookback}\")"
      comparison      = "COMPARISON_GT"
      threshold_value = each.value.threshold
      duration        = "0s"
    }
  }

  documentation {
    mime_type = "text/markdown"
    content   = <<-EOT
      flask-api is spending its error budget ${each.value.threshold}x faster than allowed.
      Runbook: run `automation/fix_crashloop.sh`, check recent deploys with
      `helm history flask-api -n platform`, then open an incident with
      `incident/slack_alert.sh` and `incident/servicenow_ticket.sh`.
    EOT
  }

  notification_channels = local.channels
}

resource "google_monitoring_alert_policy" "latency_burn" {
  display_name = "flask-api latency: fast error-budget burn"
  combiner     = "OR"
  severity     = "WARNING"

  conditions {
    display_name = "Latency SLO burn rate > 14.4x over 1h"
    condition_threshold {
      filter          = "select_slo_burn_rate(\"${google_monitoring_slo.latency.id}\", \"3600s\")"
      comparison      = "COMPARISON_GT"
      threshold_value = 14.4
      duration        = "0s"
    }
  }

  notification_channels = local.channels
}

output "slo_availability" { value = google_monitoring_slo.availability.id }
output "slo_latency" { value = google_monitoring_slo.latency.id }
