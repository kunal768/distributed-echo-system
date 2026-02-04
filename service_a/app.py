from flask import Flask, request, jsonify, g
import time
import logging
from logging_utils import setup_logging

app = Flask(__name__)
logger = setup_logging('service_a')


@app.before_request
def before_request():
    """Record request start time for latency calculation."""
    g.start_time = time.time()


@app.after_request
def after_request(response):
    """Log request details including latency."""
    latency_ms = (time.time() - g.start_time) * 1000
    logger.info(
        f"{request.method} {request.path} {response.status_code} {latency_ms:.2f}ms"
    )
    return response


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint."""
    return jsonify({"status": "ok"}), 200


@app.route('/echo', methods=['GET'])
def echo():
    """Echo endpoint that returns the message parameter."""
    msg = request.args.get('msg', '')
    return jsonify({"echo": msg}), 200


if __name__ == '__main__':
    app.run(host="127.0.0.1", port=8080, debug=False)
