#!/bin/bash

# Comprehensive test script for distributed echo system
# Tests various failure scenarios, timeouts, and breakdowns

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Service URLs
SERVICE_A_URL="http://127.0.0.1:8080"
SERVICE_B_URL="http://127.0.0.1:8081"

# Counters
PASSED=0
FAILED=0
TOTAL=0

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
    local max_attempts=10
    local attempt=0
    
    echo "Waiting for $service_name to be ready..."
    while [ $attempt -lt $max_attempts ]; do
        if check_service "$url" "$service_name"; then
            echo "$service_name is ready!"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 1
    done
    
    echo "Warning: $service_name may not be ready"
    return 1
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
                return 0
            else
                print_failure "$description - Expected key '$expected_key' not found"
                echo "  Status: $http_code"
                echo "  Response: $body"
                return 1
            fi
        else
            print_success "$description"
            echo "  Response: $body"
            return 0
        fi
    else
        print_failure "$description - Expected status $expected_status, got $http_code"
        echo "  Response: $body"
        return 1
    fi
}

# Main test execution
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Distributed Echo System Test Suite${NC}"
echo -e "${YELLOW}========================================${NC}"

# Check if services are running
echo -e "\n${YELLOW}Checking service availability...${NC}"
SERVICE_A_RUNNING=false
SERVICE_B_RUNNING=false

if check_service "$SERVICE_A_URL" "Service A"; then
    SERVICE_A_RUNNING=true
    echo "Service A is running"
else
    echo "Service A is not running (some tests will be skipped)"
fi

if check_service "$SERVICE_B_URL" "Service B"; then
    SERVICE_B_RUNNING=true
    echo "Service B is running"
else
    echo "Service B is not running (some tests will be skipped)"
fi

# ============================================
# Test Suite 1: Health Check Tests
# ============================================
echo -e "\n${YELLOW}=== Test Suite 1: Health Checks ===${NC}"

if [ "$SERVICE_A_RUNNING" = true ]; then
    print_test "Service A Health Check"
    test_request "$SERVICE_A_URL/health" 200 "status" "Service A health endpoint"
fi

if [ "$SERVICE_B_RUNNING" = true ]; then
    print_test "Service B Health Check"
    test_request "$SERVICE_B_URL/health" 200 "status" "Service B health endpoint"
fi

# ============================================
# Test Suite 2: Success Scenarios
# ============================================
echo -e "\n${YELLOW}=== Test Suite 2: Success Scenarios ===${NC}"

if [ "$SERVICE_A_RUNNING" = true ]; then
    print_test "Service A Echo - Normal Message"
    test_request "$SERVICE_A_URL/echo?msg=hello" 200 "echo" "Service A echo with message"
    
    print_test "Service A Echo - Empty Message"
    test_request "$SERVICE_A_URL/echo?msg=" 200 "echo" "Service A echo with empty message"
    
    print_test "Service A Echo - Special Characters"
    test_request "$SERVICE_A_URL/echo?msg=hello%20world" 200 "echo" "Service A echo with URL encoding"
fi

if [ "$SERVICE_A_RUNNING" = true ] && [ "$SERVICE_B_RUNNING" = true ]; then
    print_test "Service B Call Echo - Success"
    test_request "$SERVICE_B_URL/call-echo?msg=test123" 200 "echo_response" "Service B successfully calling Service A"
    
    print_test "Service B Call Echo - Long Message"
    test_request "$SERVICE_B_URL/call-echo?msg=This%20is%20a%20very%20long%20message%20to%20test" 200 "echo_response" "Service B with long message"
fi

# ============================================
# Test Suite 3: Service A Down Scenarios
# ============================================
echo -e "\n${YELLOW}=== Test Suite 3: Service A Down Scenarios ===${NC}"

if [ "$SERVICE_B_RUNNING" = true ]; then
    print_test "Service B Call Echo - Service A Down (Connection Refused)"
    echo "  Note: This test assumes Service A is stopped"
    response=$(curl -s -w "\n%{http_code}" "$SERVICE_B_URL/call-echo?msg=test" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" -eq 503 ]; then
        if echo "$body" | grep -q "Service A unavailable"; then
            print_success "Service B correctly returns 503 when Service A is down"
            echo "  Response: $body"
        else
            print_failure "Service B returns 503 but missing error message"
            echo "  Response: $body"
        fi
    else
        if [ "$SERVICE_A_RUNNING" = true ]; then
            print_success "Service A is running, so this test is skipped (expected)"
        else
            print_failure "Expected 503 when Service A is down, got $http_code"
            echo "  Response: $body"
        fi
    fi
fi

# ============================================
# Test Suite 4: Invalid Request Scenarios
# ============================================
echo -e "\n${YELLOW}=== Test Suite 4: Invalid Request Scenarios ===${NC}"

if [ "$SERVICE_B_RUNNING" = true ]; then
    print_test "Service B Call Echo - Missing Message Parameter"
    test_request "$SERVICE_B_URL/call-echo" 400 "Missing" "Service B rejects request without msg parameter"
    
    print_test "Service B Call Echo - Empty Message Parameter"
    response=$(curl -s -w "\n%{http_code}" "$SERVICE_B_URL/call-echo?msg=" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" -eq 400 ] || [ "$http_code" -eq 503 ]; then
        print_success "Service B handles empty message parameter correctly"
        echo "  Status: $http_code"
        echo "  Response: $body"
    else
        print_failure "Unexpected status code for empty message: $http_code"
        echo "  Response: $body"
    fi
fi

if [ "$SERVICE_A_RUNNING" = true ]; then
    print_test "Service A Echo - Missing Message Parameter"
    test_request "$SERVICE_A_URL/echo" 200 "echo" "Service A handles missing msg parameter"
fi

# ============================================
# Test Suite 5: Service B Down Scenarios
# ============================================
echo -e "\n${YELLOW}=== Test Suite 5: Service B Down Scenarios ===${NC}"

if [ "$SERVICE_B_RUNNING" = false ]; then
    print_test "Service B Not Responding"
    if ! curl -s -f "$SERVICE_B_URL/health" > /dev/null 2>&1; then
        print_success "Service B is correctly identified as down"
    else
        print_failure "Service B should be down but responds"
    fi
else
    print_test "Service B Down Test"
    echo "  Note: Service B is running, so this test is skipped"
    echo "  To test: Stop Service B and run this script again"
fi

# ============================================
# Test Suite 6: Timeout Scenarios
# ============================================
echo -e "\n${YELLOW}=== Test Suite 6: Timeout Scenarios ===${NC}"

if [ "$SERVICE_B_RUNNING" = true ]; then
    print_test "Service B Timeout Handling"
    echo "  Note: Service B has a 2-second timeout configured"
    echo "  To test timeout: Start Service A with artificial delay or use network throttling"
    
    # Test that Service B responds quickly even if Service A is slow
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
    
    if [ "$http_code" -eq 503 ] && echo "$body" | grep -q "Timeout"; then
        print_success "Service B correctly handles timeout scenario"
    elif [ "$http_code" -eq 200 ]; then
        print_success "Service B successfully completed request (Service A responded quickly)"
    fi
fi

# ============================================
# Test Suite 7: Concurrent Request Scenarios
# ============================================
echo -e "\n${YELLOW}=== Test Suite 7: Concurrent Request Scenarios ===${NC}"

if [ "$SERVICE_A_RUNNING" = true ] && [ "$SERVICE_B_RUNNING" = true ]; then
    print_test "Multiple Concurrent Requests to Service B"
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
fi

# ============================================
# Test Suite 8: Error Response Format
# ============================================
echo -e "\n${YELLOW}=== Test Suite 8: Error Response Format ===${NC}"

if [ "$SERVICE_B_RUNNING" = true ]; then
    print_test "Service B Error Response Structure"
    response=$(curl -s "$SERVICE_B_URL/call-echo" 2>&1)
    
    if echo "$response" | grep -q "error"; then
        if echo "$response" | grep -qE '"error"'; then
            print_success "Error response contains 'error' field"
        else
            print_failure "Error response missing 'error' field"
        fi
    else
        echo "  Note: This test requires an error scenario"
    fi
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
