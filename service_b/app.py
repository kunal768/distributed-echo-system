from flask import Flask, request, jsonify, g
import time
import os
import requests
from requests.exceptions import Timeout, ConnectionError, RequestException
from logging_utils import setup_logging

app = Flask(__name__)
logger = setup_logging('service_b')

# Service A URL - use environment variable if set (for Docker), otherwise default to localhost
SERVICE_A_URL = os.getenv('SERVICE_A_URL', 'http://127.0.0.1:8080')
TIMEOUT_SECONDS = 2.0


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


@app.route('/call-echo', methods=['GET'])
def call_echo():
    """Call Service A's echo endpoint and return combined response."""
    msg = request.args.get('msg', '')
    
    if not msg:
        return jsonify({"error": "Missing 'msg' parameter"}), 400
    
    # Construct Service A URL
    service_a_echo_url = f"{SERVICE_A_URL}/echo?msg={msg}"
    
    try:
        logger.info(f"Calling Service A: {service_a_echo_url} (timeout={TIMEOUT_SECONDS}s)")
        
        # Make request to Service A with timeout
        response = requests.get(service_a_echo_url, timeout=TIMEOUT_SECONDS)
        
        # Log successful outbound call
        logger.info(
            f"Service A call successful: {response.status_code} - {service_a_echo_url}"
        )
        
        # Return combined response
        return jsonify({
            "msg": msg,
            "echo_response": response.json()
        }), 200
        
    except Timeout:
        error_msg = f"Timeout calling Service A after {TIMEOUT_SECONDS}s"
        logger.error(f"{error_msg} - URL: {service_a_echo_url}")
        return jsonify({
            "error": "Service A unavailable",
            "details": error_msg
        }), 503
        
    except ConnectionError as e:
        error_msg = f"Connection error: {str(e)}"
        logger.error(f"{error_msg} - URL: {service_a_echo_url}")
        return jsonify({
            "error": "Service A unavailable",
            "details": error_msg
        }), 503
        
    except RequestException as e:
        error_msg = f"Request error: {str(e)}"
        logger.error(f"{error_msg} - URL: {service_a_echo_url}")
        return jsonify({
            "error": "Service A unavailable",
            "details": error_msg
        }), 503


if __name__ == '__main__':
    app.run(host="127.0.0.1", port=8081, debug=False)
