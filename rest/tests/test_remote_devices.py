"""Tests for remote device SSH functionality"""

import pytest
from cursor_api.models.device import Device, DeviceCreate, DeviceStatus, ChatLocation
from cursor_api.services.device_service import create_device, list_devices
from cursor_api.database.device_db import init_device_db
import tempfile
import os


def test_device_create_model():
    """Test device creation model"""
    device_create = DeviceCreate(
        name="Test Server",
        hostname="test.example.com",
        username="testuser",
        port=22
    )
    
    assert device_create.name == "Test Server"
    assert device_create.hostname == "test.example.com"
    assert device_create.username == "testuser"
    assert device_create.port == 22


def test_device_status_enum():
    """Test device status enum"""
    assert DeviceStatus.fromString("online") == DeviceStatus.ONLINE
    assert DeviceStatus.fromString("offline") == DeviceStatus.OFFLINE
    assert DeviceStatus.fromString("unknown") == DeviceStatus.UNKNOWN
    assert DeviceStatus.fromString("invalid") == DeviceStatus.UNKNOWN


def test_chat_location_enum():
    """Test chat location enum"""
    assert ChatLocation.fromString("local") == ChatLocation.LOCAL
    assert ChatLocation.fromString("remote") == ChatLocation.REMOTE
    assert ChatLocation.fromString("invalid") == ChatLocation.LOCAL


def test_device_json_serialization():
    """Test device to/from JSON"""
    from datetime import datetime, timezone
    
    device = Device(
        id="test-123",
        name="Test Device",
        hostname="test.example.com",
        username="user",
        port=22,
        created_at=datetime.now(timezone.utc),
        status=DeviceStatus.ONLINE,
    )
    
    json_data = device.dict()
    assert json_data["id"] == "test-123"
    assert json_data["name"] == "Test Device"
    assert json_data["hostname"] == "test.example.com"
    assert json_data["port"] == 22
    assert json_data["status"] == "online"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

