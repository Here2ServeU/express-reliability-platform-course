from flask import Flask, jsonify, request
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import os

app = Flask(__name__)

# NEW: counters and timers that Prometheus will read
REQUEST_COUNT = Counter(
    'flask_api_requests_total',
    'Total number of requests to flask-api',
    ['method', 'endpoint', 'status']
)
REQUEST_LATENCY = Histogram(
    'flask_api_request_latency_seconds',
    'Request latency for flask-api'
)

# NEW: the /metrics door that Prometheus knocks on
@app.route('/metrics')
def metrics():
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

# Existing routes stay exactly the same:
@app.route('/')
def root():
    REQUEST_COUNT.labels('GET', '/', '200').inc()
    return jsonify({'service': 'flask-api', 'version': 'v4', 'status': 'running'})

@app.route('/health')
def health():
    return jsonify({'status': 'healthy', 'service': 'flask-api'})

@app.route('/score')
def score():
    with REQUEST_LATENCY.time():
        input_text = request.args.get('input', 'no input provided')
        words = len(input_text.split())
        risk_score = min(100, words * 7)
        REQUEST_COUNT.labels('GET', '/score', '200').inc()
        return jsonify({
            'input': input_text,
            'word_count': words,
            'risk_score': risk_score,
            'verdict': 'HIGH' if risk_score > 70 else 'MEDIUM' if risk_score > 40 else 'LOW'
        })

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port)
