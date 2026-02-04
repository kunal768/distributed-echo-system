import pytest
import sys
import os

# Add parent directory to path to import service_a
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'service_a'))

from service_a.app import app


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


def test_echo_endpoint(client):
    """Test that /echo returns the message correctly."""
    response = client.get('/echo?msg=test')
    assert response.status_code == 200
    data = response.get_json()
    assert data == {"echo": "test"}


def test_echo_endpoint_empty_msg(client):
    """Test that /echo handles empty message."""
    response = client.get('/echo?msg=')
    assert response.status_code == 200
    data = response.get_json()
    assert data == {"echo": ""}


def test_echo_endpoint_no_msg_param(client):
    """Test that /echo handles missing msg parameter."""
    response = client.get('/echo')
    assert response.status_code == 200
    data = response.get_json()
    assert data == {"echo": ""}
