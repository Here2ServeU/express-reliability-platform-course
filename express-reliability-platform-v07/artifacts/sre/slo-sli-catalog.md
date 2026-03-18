# SLO and SLI Catalog

## Service: web-ui
- SLI: Availability
- SLO: >= 99.9% successful requests per 30-day window
- Measurement: HTTP 2xx and 3xx responses / total requests

## Service: node-api
- SLI: Latency (p95)
- SLO: p95 < 500 ms
- Measurement: request duration histogram

## Service: flask-api
- SLI: Error rate
- SLO: < 1% 5xx responses per 1-hour window
- Measurement: 5xx responses / total responses

## Alert Thresholds
- Warning: 80% of error budget consumed
- Critical: 100% of error budget consumed
