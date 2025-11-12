"""
Shared pytest configuration and fixtures for cursor-agent REST API tests
"""

import pytest
import requests

BASE_URL = "http://localhost:8000"


def pytest_configure(config):
    """Configure pytest with custom markers"""
    config.addinivalue_line(
        "markers", "slow: marks tests as slow (making actual cursor-agent calls)"
    )
    config.addinivalue_line(
        "markers", "workflow: marks tests as end-to-end workflow tests"
    )
    config.addinivalue_line(
        "markers", "integration: marks tests as integration tests"
    )


@pytest.fixture(scope="session")
def api_base_url():
    """Base URL for API requests"""
    return BASE_URL


@pytest.fixture(scope="session", autouse=True)
def check_api_server():
    """Check that API server is running before tests start"""
    try:
        response = requests.get(BASE_URL, timeout=5)
        if response.status_code != 200:
            pytest.exit("API server is not responding correctly")
    except requests.RequestException:
        pytest.exit(
            "API server is not running. Please start it with:\n"
            "  cd /Users/davell/Documents/github/blink/rest\n"
            "  ./start_api.sh"
        )


def pytest_collection_modifyitems(config, items):
    """Automatically mark slow tests"""
    for item in items:
        # Mark tests that make cursor-agent calls as slow
        if "agent_prompt" in item.nodeid.lower():
            item.add_marker(pytest.mark.slow)
        
        # Mark workflow tests
        if "workflow" in item.nodeid.lower() or "e2e" in item.nodeid.lower():
            item.add_marker(pytest.mark.workflow)

