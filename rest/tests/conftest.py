"""Pytest configuration and shared fixtures for API tests"""

import pytest
import sys
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))


@pytest.fixture(scope="session")
def base_url():
    """Base URL for API tests"""
    return "http://localhost:8000"


@pytest.fixture(scope="session")
def api_client(base_url):
    """HTTP client for API tests"""
    import requests
    return requests.Session()
