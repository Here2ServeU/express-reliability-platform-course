from flask import Flask, request, jsonify

app = Flask(__name__)


@app.route('/health')
def health():
    return jsonify({'status': 'ok', 'service': 'flask-api', 'version': 'v2'})


@app.route('/score')
def score():
    user_input = request.args.get('input', 'default')
    word_count = len(user_input.split())
    char_count = len(user_input)
    risk_score = char_count * 7
    return jsonify({
        'input':      user_input,
        'word_count': word_count,
        'char_count': char_count,
        'risk_score': risk_score,
        'logic':      'score = characters x 7',
        'service':    'flask-api',
        'version':    'v2'
    })


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
