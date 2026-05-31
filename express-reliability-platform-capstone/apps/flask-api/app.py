from flask import Flask, jsonify
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST

app = Flask(__name__)
requests_total = Counter("flask_requests_total", "Total requests to Flask API")


@app.route("/")
def home():
    requests_total.inc()
    return "Flask API v8 running!"


@app.route("/api/health")
def health():
    requests_total.inc()
    return jsonify(status="ok", service="flask-api", version="v7")


@app.route("/metrics")
def metrics():
    return generate_latest(requests_total), 200, {"Content-Type": CONTENT_TYPE_LATEST}


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
