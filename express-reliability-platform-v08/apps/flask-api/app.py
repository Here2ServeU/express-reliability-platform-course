from flask import Flask, jsonify, request, Response
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import os
import time

app = Flask(__name__)

REQUEST_COUNT = Counter(
    'flask_api_requests_total', 'Total requests', ['status']
)
REQUEST_LATENCY = Histogram(
    'flask_api_request_latency_seconds', 'Request latency in seconds'
)


@app.before_request
def _start_timer():
    request._start_time = time.time()


@app.after_request
def _record_metrics(response):
    REQUEST_LATENCY.observe(time.time() - request._start_time)
    REQUEST_COUNT.labels(status=str(response.status_code)).inc()
    return response


@app.route('/')
def root():
    return jsonify({
        'service': 'flask-api',
        'version': 'v8',
        'status': 'running'
    })

@app.route('/metrics')
def metrics():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

@app.route('/health')
@app.route('/api/health')
def health():
    return jsonify({'service': 'flask-api', 'status': 'ok', 'version': 'v8'})

@app.route('/score')
def score():
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
