from flask import Flask, jsonify, request, g
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import os
import random
import time

app = Flask(__name__)

# Counters and timers that Prometheus (Google Managed Prometheus on GKE) reads
REQUEST_COUNT = Counter(
    'flask_api_requests_total',
    'Total number of requests to flask-api',
    ['method', 'endpoint', 'status']
)
REQUEST_LATENCY = Histogram(
    'flask_api_request_latency_seconds',
    'Request latency for flask-api'
)

# V10: chaos knob for the error-budget drill. 0.0 = healthy, 0.2 = 20% of
# /score requests fail with 503. Set with `kubectl set env` (see chaos/error_budget_burn.sh).
ERROR_RATE = float(os.environ.get('ERROR_RATE', '0'))

# Probe and scrape traffic is not user traffic, so it does not count toward the SLO.
UNTRACKED = {'/health', '/metrics'}


@app.before_request
def start_timer():
    g.start = time.perf_counter()


@app.after_request
def record(response):
    # V10: count every real request with its actual status, including 5xx,
    # so the availability SLO sees failures, not just successes.
    if request.path not in UNTRACKED:
        REQUEST_COUNT.labels(request.method, request.path, str(response.status_code)).inc()
        if request.path == '/score':
            REQUEST_LATENCY.observe(time.perf_counter() - g.start)
    return response


@app.route('/metrics')
def metrics():
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}


@app.route('/')
def root():
    return jsonify({'service': 'flask-api', 'version': 'v10', 'status': 'running'})


@app.route('/health')
def health():
    return jsonify({'status': 'healthy', 'service': 'flask-api'})


@app.route('/score')
def score():
    if ERROR_RATE and random.random() < ERROR_RATE:
        return jsonify({'error': 'injected failure (chaos drill)'}), 503
    input_text = request.args.get('input', 'no input provided')
    words = len(input_text.split())
    risk_score = min(100, words * 7)
    return jsonify({
        'input': input_text,
        'word_count': words,
        'risk_score': risk_score,
        'verdict': 'HIGH' if risk_score > 70 else 'MEDIUM' if risk_score > 40 else 'LOW'
    })


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port)
