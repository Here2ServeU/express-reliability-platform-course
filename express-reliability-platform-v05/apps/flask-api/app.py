from flask import Flask
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST
app = Flask(__name__)
c = Counter('flask_requests_total', 'Total requests to Flask API')

@app.route('/')
def home():
    c.inc()
    return 'Flask API v4 running!'

@app.route('/metrics')
def metrics():
    return generate_latest(c), 200, {'Content-Type': CONTENT_TYPE_LATEST}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)