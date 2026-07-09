from flask import Flask, jsonify
import os

app = Flask(__name__)

APP_VERSION = os.getenv("APP_VERSION", "1.0.0")


@app.route("/")
def hello():
    return jsonify({"message": "Hello from CI/CD demo!", "version": APP_VERSION})


@app.route("/health")
def health():
    return jsonify({"status": "healthy"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
