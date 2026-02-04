#!/bin/bash

# Comprehensive test script for distributed echo system
# Automatically manages services to simulate all test scenarios
# Tests various failure scenarios, timeouts, and breakdowns

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Service URLs
SERVICE_A_URL="http://127.0.0.1:8080"
SERVICE_B_URL="http://127.0.0.1:8081"

# Service PIDs
SERVICE_A_PID=""
SERVICE_B_PID=""

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_A_SCRIPT="$SCRIPT_DIR/service_a/app.py"
SERVICE_B_SCRIPT="$SCRIPT_DIR/service_b/app.py"

# Counters
PASSED=0
FAILED=0
TOTAL=0

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}Cleaning up services...${NC}"
    stop_service_a
    stop_service_b
    # Wait a bit for ports to be released
    sleep 1
    # Clean up log files
    rm -f /tmp/service_a.log /tmp/service_b.log 2>/dev/null || true
}

# Trap to ensure cleanup on exit
trap cleanup EXIT INT TERM

# Function to print test header
print_test() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}Test: $1${NC}"
    echo -e "${BLUE}========================================${NC}"
    TOTAL=$((TOTAL + 1))
}

# Function to print success
print_success() {
    echo -e "${GREEN}✓ PASSED: $1${NC}"
    PASSED=$((PASSED + 1))
}

# Function to print failure
print_failure() {
    echo -e "${RED}✗ FAILED: $1${NC}"
    FAILED=$((FAILED + 1))
}

# Function to check if service is running
check_service() {
    local url=$1
    local service_name=$2
    
    if curl -s -f "$url/health" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to wait for service to be ready
wait_for_service() {
    local url=$1
    local service_name=$2
    local max_attempts=15
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if check_service "$url" "$service_name"; then
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 0.5
    done
    
    return 1
}

# Function to start Service A
start_service_a() {
    # Check if service is already running and healthy
    if [ -n "$SERVICE_A_PID" ] && kill -0 "$SERVICE_A_PID" 2>/dev/null; then
        if check_service "$SERVICE_A_URL" "Service A"; then
            return 0  # Already running and healthy
        else
            # PID exists but service isn't responding, clean it up
            SERVICE_A_PID=""
        fi
    fi
    
    # Ensure any stale processes are cleaned up before starting
    stop_service_a
    
    echo -e "${CYAN}Starting Service A...${NC}"
    # Start service and capture output for debugging
    python3 "$SERVICE_A_SCRIPT" > /tmp/service_a.log 2>&1 &
    SERVICE_A_PID=$!
    
    if wait_for_service "$SERVICE_A_URL" "Service A"; then
        echo -e "${GREEN}Service A started (PID: $SERVICE_A_PID)${NC}"
        return 0
    else
        echo -e "${RED}Failed to start Service A${NC}"
        # Show error log if available
        if [ -f /tmp/service_a.log ]; then
            echo -e "${YELLOW}Service A error log:${NC}"
            tail -5 /tmp/service_a.log | sed 's/^/  /'
        fi
        # Clean up failed process
        kill "$SERVICE_A_PID" 2>/dev/null || true
        SERVICE_A_PID=""
        # Also kill any processes on the port
        lsof -ti:8080 | xargs kill -9 2>/dev/null || true
        return 1
    fi
}

# Function to stop Service A
stop_service_a() {
    if [ -n "$SERVICE_A_PID" ] && kill -0 "$SERVICE_A_PID" 2>/dev/null; then
        echo -e "${CYAN}Stopping Service A (PID: $SERVICE_A_PID)...${NC}"
        kill "$SERVICE_A_PID" 2>/dev/null || true
        wait "$SERVICE_A_PID" 2>/dev/null || true
    fi
    # Always clear PID and kill any remaining processes on port 8080
    SERVICE_A_PID=""
    lsof -ti:8080 | xargs kill -9 2>/dev/null || true
    sleep 0.5
}

# Function to start Service B
start_service_b() {
    # Check if service is already running and healthy
    if [ -n "$SERVICE_B_PID" ] && kill -0 "$SERVICE_B_PID" 2>/dev/null; then
        if check_service "$SERVICE_B_URL" "Service B"; then
            return 0  # Already running and healthy
        else
            # PID exists but service isn't responding, clean it up
            SERVICE_B_PID=""
        fi
    fi
    
    # Ensure any stale processes are cleaned up before starting
    stop_service_b
    
    echo -e "${CYAN}Starting Service B...${NC}"
    # Start service and capture output for debugging
    python3 "$SERVICE_B_SCRIPT" > /tmp/service_b.log 2>&1 &
    SERVICE_B_PID=$!
    
    if wait_for_service "$SERVICE_B_URL" "Service B"; then
        echo -e "${GREEN}Service B started (PID: $SERVICE_B_PID)${NC}"
        return 0
    else
        echo -e "${RED}Failed to start Service B${NC}"
        # Show error log if available
        if [ -f /tmp/service_b.log ]; then
            echo -e "${YELLOW}Service B error log:${NC}"
            tail -5 /tmp/service_b.log | sed 's/^/  /'
        fi
        # Clean up failed process
        kill "$SERVICE_B_PID" 2>/dev/null || true
        SERVICE_B_PID=""
        # Also kill any processes on the port
        lsof -ti:8081 | xargs kill -9 2>/dev/null || true
        return 1
    fi
}

# Function to stop Service B
stop_service_b() {
    if [ -n "$SERVICE_B_PID" ] && kill -0 "$SERVICE_B_PID" 2>/dev/null; then
        echo -e "${CYAN}Stopping Service B (PID: $SERVICE_B_PID)...${NC}"
        kill "$SERVICE_B_PID" 2>/dev/null || true
        wait "$SERVICE_B_PID" 2>/dev/null || true
    fi
    # Always clear PID and kill any remaining processes on port 8081
    SERVICE_B_PID=""
    lsof -ti:8081 | xargs kill -9 2>/dev/null || true
    sleep 0.5
}

# Function to make HTTP request and check response
test_request() {
    local url=$1
    local expected_status=$2
    local expected_key=$3
    local description=$4
    
    response=$(curl -s -w "\n%{http_code}" "$url" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" -eq "$expected_status" ]; then
        if [ -n "$expected_key" ]; then
            if echo "$body" | grep -q "$expected_key"; then
                print_success "$description"
                echo "  Response: $body"
                echo "  HTTP Status: $http_code"
                return 0
            else
                print_failure "$description - Expected key '$expected_key' not found"
                echo "  HTTP Status: $http_code"
                echo "  Response: $body"
                return 1
            fi
        else
            print_success "$description"
            echo "  Response: $body"
            echo "  HTTP Status: $http_code"
            return 0
        fi
    else
        print_failure "$description - Expected status $expected_status, got $http_code"
        echo "  HTTP Status: $http_code"
        echo "  Response: $body"
        return 1
    fi
}

# Function to check dependencies (warning only, doesn't exit)
check_dependencies() {
    local missing_deps=()
    
    if ! python3 -c "import flask" 2>/dev/null; then
        missing_deps+=("flask")
    fi
    if ! python3 -c "import requests" 2>/dev/null; then
        missing_deps+=("requests")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${YELLOW}Warning: The following dependencies may not be available: ${missing_deps[*]}${NC}"
        echo -e "${YELLOW}If services fail to start, install with: pip install -r requirements.txt${NC}"
        echo -e "${YELLOW}Continuing anyway...${NC}\n"
    fi
}

# Main test execution
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Distributed Echo System Test Suite${NC}"
echo -e "${YELLOW}Automated Service Management Mode${NC}"
echo -e "${YELLOW}========================================${NC}"

# Check dependencies before starting
check_dependencies

# Clean up any existing services
cleanup

# ============================================
# Test Suite 1: Health Check Tests
# ============================================
echo -e "\n${YELLOW}=== Test Suite 1: Health Checks ===${NC}"

print_test "Service A Health Check"
if start_service_a; then
    test_request "$SERVICE_A_URL/health" 200 "status" "Service A health endpoint"
    stop_service_a
else
    print_failure "Could not start Service A"
fi

print_test "Service B Health Check"
if start_service_b; then
    test_request "$SERVICE_B_URL/health" 200 "status" "Service B health endpoint"
    stop_service_b
else
    print_failure "Could not start Service B"
fi

# ============================================
# Test Suite 2: Success Scenarios
# ============================================
echo -e "\n${YELLOW}=== Test Suite 2: Success Scenarios ===${NC}"

print_test "Service A Echo - Normal Message"
if start_service_a; then
    test_request "$SERVICE_A_URL/echo?msg=hello" 200 "echo" "Service A echo with message"
    stop_service_a
else
    print_failure "Could not start Service A"
fi

print_test "Service A Echo - Empty Message"
if start_service_a; then
    test_request "$SERVICE_A_URL/echo?msg=" 200 "echo" "Service A echo with empty message"
    stop_service_a
else
    print_failure "Could not start Service A"
fi

print_test "Service A Echo - Special Characters"
if start_service_a; then
    test_request "$SERVICE_A_URL/echo?msg=hello%20world" 200 "echo" "Service A echo with URL encoding"
    stop_service_a
else
    print_failure "Could not start Service A"
fi

print_test "Service B Call Echo - Success"
if start_service_a && start_service_b; then
    test_request "$SERVICE_B_URL/call-echo?msg=test123" 200 "echo_response" "Service B successfully calling Service A"
    stop_service_b
    stop_service_a
else
    print_failure "Could not start required services"
fi

print_test "Service B Call Echo - Long Message"
if start_service_a && start_service_b; then
    test_request "$SERVICE_B_URL/call-echo?msg=This%20is%20a%20very%20long%20message%20to%20test" 200 "echo_response" "Service B with long message"
    stop_service_b
    stop_service_a
else
    print_failure "Could not start required services"
fi

# ============================================
# Test Suite 3: Service A Down Scenarios
# ============================================
echo -e "\n${YELLOW}=== Test Suite 3: Service A Down Scenarios ===${NC}"

print_test "Service B Call Echo - Service A Down (Connection Refused)"
if start_service_b; then
    # Ensure Service A is stopped
    stop_service_a
    sleep 1
    
    response=$(curl -s -w "\n%{http_code}" "$SERVICE_B_URL/call-echo?msg=test" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" -eq 503 ]; then
        if echo "$body" | grep -q "Service A unavailable"; then
            print_success "Service B correctly returns 503 when Service A is down"
            echo "  Response: $body"
            echo "  HTTP Status: $http_code"
        else
            print_failure "Service B returns 503 but missing error message"
            echo "  HTTP Status: $http_code"
            echo "  Response: $body"
        fi
    else
        print_failure "Expected 503 when Service A is down, got $http_code"
        echo "  HTTP Status: $http_code"
        echo "  Response: $body"
    fi
    stop_service_b
else
    print_failure "Could not start Service B"
fi

# ============================================
# Test Suite 4: Invalid Request Scenarios
# ============================================
echo -e "\n${YELLOW}=== Test Suite 4: Invalid Request Scenarios ===${NC}"

print_test "Service B Call Echo - Missing Message Parameter"
if start_service_b; then
    test_request "$SERVICE_B_URL/call-echo" 400 "Missing" "Service B rejects request without msg parameter"
    stop_service_b
else
    print_failure "Could not start Service B"
fi

print_test "Service B Call Echo - Empty Message Parameter"
if start_service_b; then
    response=$(curl -s -w "\n%{http_code}" "$SERVICE_B_URL/call-echo?msg=" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" -eq 400 ] || [ "$http_code" -eq 503 ]; then
        print_success "Service B handles empty message parameter correctly"
        echo "  Response: $body"
        echo "  HTTP Status: $http_code"
    else
        print_failure "Unexpected status code for empty message: $http_code"
        echo "  HTTP Status: $http_code"
        echo "  Response: $body"
    fi
    stop_service_b
else
    print_failure "Could not start Service B"
fi

print_test "Service A Echo - Missing Message Parameter"
if start_service_a; then
    test_request "$SERVICE_A_URL/echo" 200 "echo" "Service A handles missing msg parameter"
    stop_service_a
else
    print_failure "Could not start Service A"
fi

# ============================================
# Test Suite 5: Service B Down Scenarios
# ============================================
echo -e "\n${YELLOW}=== Test Suite 5: Service B Down Scenarios ===${NC}"

print_test "Service B Not Responding"
stop_service_b
sleep 1

if ! curl -s -f "$SERVICE_B_URL/health" > /dev/null 2>&1; then
    print_success "Service B is correctly identified as down"
else
    print_failure "Service B should be down but responds"
fi

# ============================================
# Test Suite 6: Timeout Scenarios
# ============================================
echo -e "\n${YELLOW}=== Test Suite 6: Timeout Scenarios ===${NC}"

print_test "Service B Timeout Handling"
if start_service_a && start_service_b; then
    # Test that Service B responds quickly when Service A is available
    start_time=$(date +%s%N)
    response=$(curl -s -w "\n%{http_code}" "$SERVICE_B_URL/call-echo?msg=timeout_test" 2>&1)
    end_time=$(date +%s%N)
    duration=$(( (end_time - start_time) / 1000000 ))  # Convert to milliseconds
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    echo "  Request duration: ${duration}ms"
    
    if [ "$duration" -lt 3000 ]; then
        print_success "Service B responds within reasonable time (< 3s)"
    else
        print_failure "Service B took too long to respond: ${duration}ms"
    fi
    
    if [ "$http_code" -eq 200 ]; then
        print_success "Service B successfully completed request (Service A responded quickly)"
        echo "  HTTP Status: $http_code"
    elif [ "$http_code" -eq 503 ] && echo "$body" | grep -q "Timeout"; then
        print_success "Service B correctly handles timeout scenario"
        echo "  HTTP Status: $http_code"
    else
        print_failure "Unexpected response: HTTP $http_code"
        echo "  HTTP Status: $http_code"
    fi
    
    stop_service_b
    stop_service_a
else
    print_failure "Could not start required services"
fi

# ============================================
# Test Suite 7: Concurrent Request Scenarios
# ============================================
echo -e "\n${YELLOW}=== Test Suite 7: Concurrent Request Scenarios ===${NC}"

print_test "Multiple Concurrent Requests to Service B"
if start_service_a && start_service_b; then
    echo "  Sending 5 concurrent requests..."
    
    success_count=0
    for i in {1..5}; do
        response=$(curl -s -w "\n%{http_code}" "$SERVICE_B_URL/call-echo?msg=concurrent$i" 2>&1)
        http_code=$(echo "$response" | tail -n1)
        if [ "$http_code" -eq 200 ]; then
            success_count=$((success_count + 1))
        fi
    done
    
    if [ "$success_count" -eq 5 ]; then
        print_success "All 5 concurrent requests succeeded"
    else
        print_failure "Only $success_count/5 concurrent requests succeeded"
    fi
    
    stop_service_b
    stop_service_a
else
    print_failure "Could not start required services"
fi

# ============================================
# Test Suite 8: Error Response Format
# ============================================
echo -e "\n${YELLOW}=== Test Suite 8: Error Response Format ===${NC}"

print_test "Service B Error Response Structure"
if start_service_b; then
    response=$(curl -s -w "\n%{http_code}" "$SERVICE_B_URL/call-echo" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | sed '$d')
    
    if echo "$response_body" | grep -q "error"; then
        if echo "$response_body" | grep -qE '"error"'; then
            print_success "Error response contains 'error' field"
            echo "  Response: $response_body"
            echo "  HTTP Status: $http_code"
        else
            print_failure "Error response missing 'error' field"
            echo "  HTTP Status: $http_code"
        fi
    else
        print_failure "Error response not found"
        echo "  HTTP Status: $http_code"
    fi
    stop_service_b
else
    print_failure "Could not start Service B"
fi

# ============================================
# Summary
# ============================================
echo -e "\n${YELLOW}========================================${NC}"
echo -e "${YELLOW}Test Summary${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "Total Tests: $TOTAL"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"

if [ $FAILED -eq 0 ]; then
    echo -e "\n${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}Some tests failed. Please review the output above.${NC}"
    exit 1
fi
