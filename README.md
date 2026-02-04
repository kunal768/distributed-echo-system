# Distributed Echo System

A two-service distributed system demonstrating inter-service communication, logging, and failure handling. Service B acts as a client that calls Service A's echo endpoint.

## Quick Start

**⚠️ IMPORTANT: Virtual environment is REQUIRED. All commands must be run with venv activated.**

```bash
# 1. Create and activate virtual environment (REQUIRED)
cd distributed-echo-system
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# 2. Install dependencies (REQUIRED)
pip install -r requirements.txt

# 3. Run automated tests (venv must be activated)
chmod +x test_scenarios.sh
./test_scenarios.sh
```

## Architecture

Two independent Flask services communicating over HTTP:

- **Service A** (Port 8080): Echo API server
- **Service B** (Port 8081): Client API server that calls Service A

```
Client → Service B (8081) → Service A (8080) → Service B → Client
```

**What Makes This Distributed?**
- Two independent processes that can fail independently
- Network boundary (HTTP communication)
- No shared state between services
- Graceful failure handling (Service B handles Service A unavailability)

## Setup Instructions

### Prerequisites

- Python 3.10 or higher
- pip (Python package manager)
- curl (for testing)

### Installation

**⚠️ Virtual environment is MANDATORY. Do not skip this step.**

1. **Create and activate virtual environment:**

   ```bash
   cd distributed-echo-system
   python3 -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

   **Verify venv is active:** Your prompt should show `(venv)`. If not, activate it again.

2. **Install dependencies:**

   ```bash
   pip install -r requirements.txt
   ```

   This installs: Flask, requests, pytest, and gunicorn.

**⚠️ Remember: Always activate venv before running any Python commands or test scripts.**

## Manual Testing

### Prerequisites

- Virtual environment activated (`source venv/bin/activate`)
- Dependencies installed (`pip install -r requirements.txt`)

### Step 1: Start Service A

**Terminal 1:**

```bash
cd distributed-echo-system
source venv/bin/activate  # Ensure venv is activated
python service_a/app.py
```

Service A will start on `http://127.0.0.1:8080`

### Step 2: Start Service B

**Terminal 2:**

```bash
cd distributed-echo-system
source venv/bin/activate  # Ensure venv is activated
python service_b/app.py
```

Service B will start on `http://127.0.0.1:8081`

### Step 3: Test Service A Endpoints

**Health Check:**
```bash
curl -w "\nHTTP Status: %{http_code}\n" http://127.0.0.1:8080/health
# Expected: {"status":"ok"}
# HTTP Status: 200
```

**Echo Endpoint:**
```bash
curl -w "\nHTTP Status: %{http_code}\n" "http://127.0.0.1:8080/echo?msg=hello"
# Expected: {"echo":"hello"}
# HTTP Status: 200
```

**Echo with Empty Message:**
```bash
curl -w "\nHTTP Status: %{http_code}\n" "http://127.0.0.1:8080/echo?msg="
# Expected: {"echo":""}
# HTTP Status: 200
```

**Echo without Parameter:**
```bash
curl -w "\nHTTP Status: %{http_code}\n" http://127.0.0.1:8080/echo
# Expected: {"echo":""}
# HTTP Status: 200
```

### Step 4: Test Service B Endpoints

**Health Check:**
```bash
curl -w "\nHTTP Status: %{http_code}\n" http://127.0.0.1:8081/health
# Expected: {"status":"ok"}
# HTTP Status: 200
```

**Call Echo (Success - Service A Running):**
```bash
curl -w "\nHTTP Status: %{http_code}\n" "http://127.0.0.1:8081/call-echo?msg=hello"
# Expected: {"msg":"hello","echo_response":{"echo":"hello"}}
# HTTP Status: 200
```

**Call Echo (Missing Parameter):**
```bash
curl -w "\nHTTP Status: %{http_code}\n" "http://127.0.0.1:8081/call-echo"
# Expected: {"error":"Missing 'msg' parameter"}
# HTTP Status: 400
```

**Call Echo (Empty Parameter):**
```bash
curl -w "\nHTTP Status: %{http_code}\n" "http://127.0.0.1:8081/call-echo?msg="
# Expected: {"error":"Missing 'msg' parameter"}
# HTTP Status: 400
```

### Step 5: Test Failure Scenarios

**Service A Down (Connection Refused):**

1. Stop Service A (Ctrl+C in Terminal 1)
2. Keep Service B running
3. Test Service B:

```bash
curl -w "\nHTTP Status: %{http_code}\n" "http://127.0.0.1:8081/call-echo?msg=hello"
# Expected: {"error":"Service A unavailable","details":"Connection error: ..."}
# HTTP Status: 503
```

**Note:** The response body shows the error details, and the HTTP status code (503) is displayed at the end. Check Service B's terminal logs for detailed error information.

**Service B Down:**

1. Stop Service B (Ctrl+C in Terminal 2)
2. Test health check:

```bash
curl http://127.0.0.1:8081/health
# Expected: curl: (7) Failed to connect to 127.0.0.1 port 8081: Connection refused
```

## Automated Testing

**⚠️ Virtual environment MUST be activated before running the test script.**

The test script automatically manages services - starting and stopping them as needed for each test scenario.

```bash
cd distributed-echo-system
source venv/bin/activate  # REQUIRED: Activate venv first
chmod +x test_scenarios.sh
./test_scenarios.sh
```

**What the script does:**
- Automatically starts/stops services for each test
- Tests all scenarios: success, failures, timeouts, concurrent requests
- Provides color-coded pass/fail results
- Shows comprehensive test summary

**Test Suites:**
1. Health Checks - Verify both services respond
2. Success Scenarios - Normal operation with both services running
3. Service A Down - Error handling when Service A is unavailable
4. Invalid Requests - Malformed request handling
5. Service B Down - Detection when Service B is not responding
6. Timeout Scenarios - Timeout handling (2-second timeout)
7. Concurrent Requests - Multiple simultaneous requests
8. Error Response Format - JSON error structure validation


## API Endpoints

### Service A (Port 8080)

- **GET /health**: Health check
  - Returns: `{"status": "ok"}` (HTTP 200)

- **GET /echo?msg=<message>**: Echo endpoint
  - Returns: `{"echo": "<message>"}` (HTTP 200)
  - Missing `msg` parameter returns empty string

### Service B (Port 8081)

- **GET /health**: Health check
  - Returns: `{"status": "ok"}` (HTTP 200)

- **GET /call-echo?msg=<message>**: Calls Service A's echo endpoint
  - **Success**: `{"msg": "<message>", "echo_response": {"echo": "<message>"}}` (HTTP 200)
  - **Failure**: `{"error": "Service A unavailable", "details": "<error>"}` (HTTP 503)
  - **Invalid**: `{"error": "Missing 'msg' parameter"}` (HTTP 400)

## Logging

Both services log requests with the format:
```
%(asctime)s %(levelname)s %(name)s %(message)s
```

Each request logs:
- Service name (`service_a` or `service_b`)
- HTTP method and path
- HTTP status code
- Request latency in milliseconds

**Example:**
```
2024-01-01 12:00:00 INFO service_b GET /call-echo 200 45.23ms
2024-01-01 12:00:01 INFO service_a GET /echo 200 2.15ms
```

Service B also logs outbound calls to Service A with URL, timeout, and success/failure status.

## Error Handling

Service B implements robust error handling:

1. **Timeout (2 seconds)**: Returns HTTP 503 with timeout error message
2. **Connection Errors**: Returns HTTP 503 when Service A is down/unreachable
3. **Invalid Requests**: Returns HTTP 400 for missing required parameters

All errors are logged with context (URL, timeout, exception type) for debugging.

## Request Flow

1. Client → Service B: `GET /call-echo?msg=hello`
2. Service B → Service A: `GET /echo?msg=hello` (2-second timeout)
3. Service A → Service B: `{"echo": "hello"}`
4. Service B → Client: `{"msg": "hello", "echo_response": {"echo": "hello"}}`

## Project Structure

```
distributed-echo-system/
├── service_a/
│   ├── app.py              # Flask app with /health and /echo endpoints
│   └── logging_utils.py    # Logging configuration
├── service_b/
│   ├── app.py              # Flask app with /health and /call-echo endpoints
│   └── logging_utils.py    # Logging configuration
├── tests/
│   ├── test_service_a.py   # Unit tests for Service A
│   └── test_service_b.py   # Unit tests for Service B
├── requirements.txt        # Python dependencies
├── test_scenarios.sh       # Automated integration test script
└── README.md              # This file
```

## Unit Tests

Run unit tests with pytest:

```bash
cd distributed-echo-system
source venv/bin/activate  # Ensure venv is activated
pytest tests/
```

## License

This project is part of a distributed systems lab assignment.
