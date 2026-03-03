from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route("/health")
def health():
    return jsonify({"status": "flask-api healthy"})

@app.route("/score")
def score():
    user_input = request.args.get("input", "default")
    risk_score = len(user_input) * 7
    return jsonify({
        "input": user_input,
        "risk_score": risk_score,
        "logic": "Risk based on input length (placeholder)"
    })

if __name__ == "__main__":
    app.run(port=5000)
