# Distributed Echo System

A two-service distributed system demonstrating inter-service communication, logging, and failure handling. This project implements a simple echo service where Service B acts as a client that calls Service A's echo endpoint.

## Architecture

The system consists of two independent Flask services:

- **Service A** (Port 8080): Echo API server that echoes messages
- **Service B** (Port 8081): Client API server that calls Service A and handles failures

```
Client → Service B (8081) → Service A (8080) → Service B → Client
```

## What Makes This Distributed?

This system is distributed because:

1. **Two Independent Processes**: Service A and Service B run as separate processes that can be started, stopped, and fail independently.

2. **Network Boundary**: Services communicate over HTTP, crossing a network boundary (even if on localhost). This introduces network-related failures like timeouts and connection errors.

3. **Independent Failure**: Service A can fail or be stopped without affecting Service B's ability to start and handle requests. Service B gracefully handles Service A's unavailability by returning HTTP 503 errors.

4. **No Shared State**: Each service maintains its own state and logs independently.

## Project Structure

```
python-http/
├── service_a/
│   ├── app.py              # Flask app with /health and /echo endpoints
│   └── logging_utils.py    # Logging configuration
├── service_b/
│   ├── app.py              # Flask app with /health and /call-echo endpoints
│   └── logging_utils.py    # Logging configuration
├── tests/
│   ├── test_service_a.py   # Tests for Service A
│   └── test_service_b.py   # Tests for Service B
├── requirements.txt        # Python dependencies
├── README.md              # This file
└── test_scenarios.sh       # Bash script for testing failure scenarios
```

## Setup Instructions

### Prerequisites

- Python 3.10 or higher
- pip (Python package manager)

### Installation

1. **Create and activate a virtual environment:**

   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

2. **Install dependencies:**

   ```bash
   cd python-http
   pip install -r requirements.txt
   ```

## Running the Services

### Local Development

1. **Start Service A** (in Terminal 1):

   ```bash
   cd python-http
   python service_a/app.py
   ```

   Service A will start on `http://127.0.0.1:8080`

2. **Start Service B** (in Terminal 2):

   ```bash
   cd python-http
   python service_b/app.py
   ```

   Service B will start on `http://127.0.0.1:8081`


## API Endpoints

### Service A (Port 8080)

- **GET /health**: Health check endpoint
  - Returns: `{"status": "ok"}` with HTTP 200

- **GET /echo?msg=<message>**: Echo endpoint
  - Query parameter: `msg` (required)
  - Returns: `{"echo": "<message>"}` with HTTP 200

### Service B (Port 8081)

- **GET /health**: Health check endpoint
  - Returns: `{"status": "ok"}` with HTTP 200

- **GET /call-echo?msg=<message>**: Calls Service A's echo endpoint
  - Query parameter: `msg` (required)
  - Returns on success: `{"msg": "<message>", "echo_response": {"echo": "<message>"}}` with HTTP 200
  - Returns on failure: `{"error": "Service A unavailable", "details": "<error message>"}` with HTTP 503

## Example Usage

### Success Case

1. Ensure both services are running.

2. Make a request to Service B:

   ```bash
   curl "http://127.0.0.1:8081/call-echo?msg=hello"
   ```

3. Expected response:

   ```json
   {
     "msg": "hello",
     "echo_response": {
       "echo": "hello"
     }
   }
   ```

4. Check the logs in both terminals to see:
   - Service B receiving the request and calling Service A
   - Service A processing the echo request
   - Both services logging request details with latency

### Failure Case

1. Start Service B (Service A should be stopped).

2. Make a request to Service B:

   ```bash
   curl "http://127.0.0.1:8081/call-echo?msg=hello"
   ```

3. Expected response (HTTP 503):

   ```json
   {
     "error": "Service A unavailable",
     "details": "Connection error: ..."
   }
   ```

4. Check Service B's logs to see:
   - Connection error or timeout logged with details
   - Error context including URL and timeout value

## Logging

Both services implement comprehensive logging with the following format:

```
%(asctime)s %(levelname)s %(name)s %(message)s
```

Each request is logged with:
- Service name (`service_a` or `service_b`)
- HTTP method and endpoint path
- HTTP status code
- Request latency in milliseconds

Example log output:

```
2024-01-01 12:00:00 INFO service_b GET /call-echo 200 45.23ms
2024-01-01 12:00:01 INFO service_a GET /echo 200 2.15ms
```

Service B also logs outbound calls to Service A:
- Target URL
- Timeout value
- Success/failure status
- Response status code (on success)

## Error Handling

Service B implements robust error handling for Service A failures:

1. **Timeout Handling**: If Service A doesn't respond within 2 seconds, Service B returns HTTP 503 with a timeout error message.

2. **Connection Errors**: If Service A is down or unreachable, Service B catches connection errors and returns HTTP 503.

3. **Request Exceptions**: Any other request-related exceptions are caught and handled gracefully.

All errors are logged with context (URL, timeout, exception type) to aid in debugging.

## Testing

Run the test suite using pytest:

```bash
cd python-http
pytest tests/
```

The tests include:
- Unit tests for Service A endpoints
- Unit tests for Service B endpoints (with mocked Service A calls)
- Failure scenario tests (timeout, connection errors)

## Request Flow

1. Client sends request to Service B: `GET /call-echo?msg=hello`
2. Service B logs the request start and extracts the `msg` parameter
3. Service B calls Service A: `GET http://127.0.0.1:8080/echo?msg=hello` with a 2-second timeout
4. Service A processes the request, logs it, and returns `{"echo": "hello"}`
5. Service B receives the response, combines it with the original message, and logs completion
6. Service B returns the combined JSON to the client

## Timeout and Failure Scenarios

### What Happens on Timeout?

When Service A doesn't respond within 2 seconds:
1. The `requests.get()` call raises a `Timeout` exception
2. Service B catches the exception and logs the error with context
3. Service B returns HTTP 503 with an error JSON body
4. The client receives a clear error message indicating Service A is unavailable

### What Happens if Service A is Down?

When Service A is stopped or unreachable:
1. The `requests.get()` call raises a `ConnectionError` (connection refused)
2. Service B catches the exception and logs the connection error
3. Service B returns HTTP 503 with an error JSON body
4. The logs show the connection refused error with the target URL

### Using Logs for Debugging

The structured logs help debug issues:
- **Normal case**: Logs show successful requests with latency metrics
- **Failure case**: Logs show error messages with context (URL, timeout, exception type)
- **Performance**: Latency metrics help identify slow requests or bottlenecks

## Testing Failure Scenarios

A comprehensive bash script (`test_scenarios.sh`) is provided to test various failure scenarios, timeouts, and breakdowns:

```bash
chmod +x test_scenarios.sh
./test_scenarios.sh
```

The script automatically detects which services are running and executes the appropriate tests. It provides color-coded output and a summary of passed/failed tests.

### Test Suite 1: Health Checks

**Purpose**: Verify that both services are running and responding to health checks.

**Tests**:
- **Service A Health Check**: `GET /health` → Expected: HTTP 200 with `{"status": "ok"}`
- **Service B Health Check**: `GET /health` → Expected: HTTP 200 with `{"status": "ok"}`

**Expected Outcome**: Both services return HTTP 200 with correct JSON structure.

### Test Suite 2: Success Scenarios

**Purpose**: Test normal operation when both services are running correctly.

**Tests**:
- **Service A Echo - Normal Message**: `GET /echo?msg=hello` → Expected: HTTP 200 with `{"echo": "hello"}`
- **Service A Echo - Empty Message**: `GET /echo?msg=` → Expected: HTTP 200 with `{"echo": ""}`
- **Service A Echo - Special Characters**: `GET /echo?msg=hello%20world` → Expected: HTTP 200 with URL-decoded message
- **Service B Call Echo - Success**: `GET /call-echo?msg=test123` → Expected: HTTP 200 with combined response containing `echo_response`
- **Service B Call Echo - Long Message**: Tests handling of longer messages → Expected: HTTP 200 with successful echo

**Expected Outcome**: All requests succeed with HTTP 200 and correct response structure.

### Test Suite 3: Service A Down Scenarios

**Purpose**: Verify Service B's error handling when Service A is unavailable.

**Tests**:
- **Service B Call Echo - Service A Down**: `GET /call-echo?msg=test` (with Service A stopped) → Expected: HTTP 503 with error message containing "Service A unavailable"

**Expected Outcome**: 
- Service B returns HTTP 503
- Error response contains `{"error": "Service A unavailable", "details": "Connection error: ..."}`
- Service B logs the connection error with context

**Note**: This test requires Service A to be stopped. If Service A is running, the test is skipped.

### Test Suite 4: Invalid Request Scenarios

**Purpose**: Test error handling for malformed or invalid requests.

**Tests**:
- **Service B Call Echo - Missing Message Parameter**: `GET /call-echo` → Expected: HTTP 400 with error message containing "Missing"
- **Service B Call Echo - Empty Message Parameter**: `GET /call-echo?msg=` → Expected: HTTP 400 or HTTP 503 (depending on Service A availability)
- **Service A Echo - Missing Message Parameter**: `GET /echo` → Expected: HTTP 200 with `{"echo": ""}` (Service A accepts empty messages)

**Expected Outcome**: 
- Service B validates input and returns HTTP 400 for missing required parameters
- Service A gracefully handles missing parameters by returning empty echo

### Test Suite 5: Service B Down Scenarios

**Purpose**: Verify detection when Service B is not responding.

**Tests**:
- **Service B Not Responding**: Attempts to reach `GET /health` → Expected: Connection refused or timeout

**Expected Outcome**: 
- Script correctly identifies Service B as down
- Health check fails as expected

**Note**: This test only runs when Service B is actually down. If Service B is running, the test is skipped with instructions.

### Test Suite 6: Timeout Scenarios

**Purpose**: Verify Service B's timeout handling (2-second timeout configured).

**Tests**:
- **Service B Timeout Handling**: Measures response time and checks timeout behavior → Expected: Response within 3 seconds OR HTTP 503 with timeout error if Service A is slow

**Expected Outcome**:
- If Service A responds quickly: HTTP 200 within reasonable time (< 3s)
- If Service A is slow/unresponsive: HTTP 503 with timeout error message
- Request duration is logged for analysis

**Note**: To fully test timeout scenarios, Service A would need to be artificially delayed or network throttling applied.

### Test Suite 7: Concurrent Request Scenarios

**Purpose**: Stress test the system with multiple simultaneous requests.

**Tests**:
- **Multiple Concurrent Requests**: Sends 5 concurrent requests to Service B → Expected: All 5 requests succeed with HTTP 200

**Expected Outcome**: 
- All concurrent requests complete successfully
- System handles load without errors
- Each request receives correct response

**Note**: Requires both services to be running.

### Test Suite 8: Error Response Format

**Purpose**: Validate that error responses follow the expected JSON structure.

**Tests**:
- **Service B Error Response Structure**: Checks error response format → Expected: JSON contains `"error"` field

**Expected Outcome**: 
- Error responses are valid JSON
- Error responses contain `"error"` field
- Error details are properly formatted

### Running the Test Script

**Prerequisites**:
- Both services should be running for full test coverage
- `curl` must be installed
- Script must be executable (`chmod +x test_scenarios.sh`)

**Usage**:
```bash
# Make script executable (if not already)
chmod +x test_scenarios.sh

# Run all tests
./test_scenarios.sh
```

**Output**:
- Color-coded test results (green for pass, red for fail)
- Detailed response information for each test
- Summary statistics (total tests, passed, failed)
- Exit code 0 if all tests pass, 1 if any fail

**Partial Test Execution**:
The script automatically detects which services are running and skips tests that require unavailable services. This allows you to:
- Test Service B's failure handling by running only Service B
- Test success scenarios by running both services
- Test Service B down scenarios by stopping Service B

## Test Output Examples

### Success Scenario - Both Services Running

When both services are running, the test script executes all success scenarios:

```bash
$ ./test_scenarios.sh

========================================
Distributed Echo System Test Suite
========================================

Checking service availability...
Service A is running
Service B is running

=== Test Suite 1: Health Checks ===

========================================
Test: Service A Health Check
========================================
✓ PASSED: Service A health endpoint
  Response: {"status":"ok"}

========================================
Test: Service B Health Check
========================================
✓ PASSED: Service B health endpoint
  Response: {"status":"ok"}

=== Test Suite 2: Success Scenarios ===

========================================
Test: Service A Echo - Normal Message
========================================
✓ PASSED: Service A echo with message
  Response: {"echo":"hello"}

========================================
Test: Service B Call Echo - Success
========================================
✓ PASSED: Service B successfully calling Service A
  Response: {"msg":"test123","echo_response":{"echo":"test123"}}

========================================
Test: Multiple Concurrent Requests to Service B
========================================
  Sending 5 concurrent requests...
✓ PASSED: All 5 concurrent requests succeeded

========================================
Test Summary
========================================
Total Tests: 8
Passed: 8
Failed: 0

All tests passed!
```

### Failure Scenario - Service A Down

When Service A is stopped, Service B gracefully handles the failure:

```bash
$ ./test_scenarios.sh

========================================
Distributed Echo System Test Suite
========================================

Checking service availability...
Service A is not running (some tests will be skipped)
Service B is running

=== Test Suite 3: Service A Down Scenarios ===

========================================
Test: Service B Call Echo - Service A Down (Connection Refused)
========================================
  Note: This test assumes Service A is stopped
✓ PASSED: Service B correctly returns 503 when Service A is down
  Response: {"error":"Service A unavailable","details":"Connection error: HTTPConnectionPool(host='127.0.0.1', port=8080): Max retries exceeded with url: /echo?msg=test (Caused by ConnectTimeoutError(...))"}

=== Test Suite 4: Invalid Request Scenarios ===

========================================
Test: Service B Call Echo - Missing Message Parameter
========================================
✓ PASSED: Service B rejects request without msg parameter
  Response: {"error":"Missing 'msg' parameter"}

========================================
Test Summary
========================================
Total Tests: 3
Passed: 3
Failed: 0

All tests passed!
```

### Manual Test Examples

**Success Case - Service B calling Service A:**
```bash
$ curl "http://127.0.0.1:8081/call-echo?msg=hello"
{
  "msg": "hello",
  "echo_response": {
    "echo": "hello"
  }
}
```

**Failure Case - Service A unavailable:**
```bash
$ curl "http://127.0.0.1:8081/call-echo?msg=hello"
{
  "error": "Service A unavailable",
  "details": "Connection error: HTTPConnectionPool(host='127.0.0.1', port=8080): Max retries exceeded..."
}
```

**Invalid Request - Missing parameter:**
```bash
$ curl "http://127.0.0.1:8081/call-echo"
{
  "error": "Missing 'msg' parameter"
}
```

## Failure Scenario Explanation

This distributed system demonstrates several types of failures and how they are handled:

### 1. **Service Unavailability (Connection Errors)**
When Service A is stopped or unreachable, Service B detects the connection failure and returns HTTP 503 with a descriptive error message. This prevents cascading failures and provides clear feedback to clients.

**Example**: Service A crashes → Service B receives `ConnectionError` → Returns HTTP 503 with error details

### 2. **Timeout Failures**
Service B implements a 2-second timeout for calls to Service A. If Service A is slow to respond (due to load, network issues, or processing delays), Service B will timeout and return HTTP 503 instead of hanging indefinitely.

**Example**: Service A takes > 2 seconds → Service B times out → Returns HTTP 503 with timeout message

### 3. **Invalid Request Handling**
Service B validates incoming requests and returns HTTP 400 for malformed requests (e.g., missing required parameters). This prevents unnecessary calls to Service A and provides immediate feedback.

**Example**: Request missing `msg` parameter → Service B validates → Returns HTTP 400 immediately

### 4. **Graceful Degradation**
Service B continues to operate even when Service A is unavailable. It can still:
- Respond to health checks (HTTP 200)
- Validate and reject invalid requests (HTTP 400)
- Return appropriate error responses (HTTP 503)

This design ensures that partial failures don't bring down the entire system.

## License

This project is part of a distributed systems lab assignment.
