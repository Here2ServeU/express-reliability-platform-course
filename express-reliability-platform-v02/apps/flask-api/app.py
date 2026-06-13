from flask import Flask, jsonify, request
import os

app = Flask(__name__)

@app.route('/')
def root():
    return jsonify({
        'service': 'flask-api',
        'version': 'v2',
        'status': 'running'
    })

@app.route('/health')
def health():
    return jsonify({'status': 'healthy', 'service': 'flask-api'})

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
