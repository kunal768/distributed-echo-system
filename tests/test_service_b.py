import pytest
import sys
import os
from unittest.mock import patch, Mock

# Add parent directory to path to import service_b
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'service_b'))

from service_b.app import app


@pytest.fixture
def client():
    """Create a test client for the Flask app."""
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client


def test_health_endpoint(client):
    """Test that /health returns 200 and correct JSON."""
    response = client.get('/health')
    assert response.status_code == 200
    data = response.get_json()
    assert data == {"status": "ok"}


@patch('service_b.app.requests.get')
def test_call_echo_success(mock_get, client):
    """Test /call-echo with successful Service A response."""
    # Mock successful response from Service A
    mock_response = Mock()
    mock_response.status_code = 200
    mock_response.json.return_value = {"echo": "hello"}
    mock_get.return_value = mock_response
    
    response = client.get('/call-echo?msg=hello')
    assert response.status_code == 200
    data = response.get_json()
    assert data == {
        "msg": "hello",
        "echo_response": {"echo": "hello"}
    }
    
    # Verify requests.get was called correctly
    mock_get.assert_called_once_with(
        "http://127.0.0.1:8080/echo?msg=hello",
        timeout=2.0
    )


@patch('service_b.app.requests.get')
def test_call_echo_timeout(mock_get, client):
    """Test /call-echo with timeout from Service A."""
    from requests.exceptions import Timeout
    
    # Mock timeout exception
    mock_get.side_effect = Timeout("Request timed out")
    
    response = client.get('/call-echo?msg=hello')
    assert response.status_code == 503
    data = response.get_json()
    assert "error" in data
    assert data["error"] == "Service A unavailable"
    assert "details" in data


@patch('service_b.app.requests.get')
def test_call_echo_connection_error(mock_get, client):
    """Test /call-echo with connection error from Service A."""
    from requests.exceptions import ConnectionError
    
    # Mock connection error
    mock_get.side_effect = ConnectionError("Connection refused")
    
    response = client.get('/call-echo?msg=hello')
    assert response.status_code == 503
    data = response.get_json()
    assert "error" in data
    assert data["error"] == "Service A unavailable"
    assert "details" in data


def test_call_echo_missing_msg_param(client):
    """Test /call-echo with missing msg parameter."""
    response = client.get('/call-echo')
    assert response.status_code == 400
    data = response.get_json()
    assert "error" in data
    assert "Missing 'msg' parameter" in data["error"]
