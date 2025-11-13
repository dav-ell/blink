"""Device and remote chat models"""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field
from enum import Enum


class DeviceStatus(str, Enum):
    """Device connection status"""
    ONLINE = "online"
    OFFLINE = "offline"
    UNKNOWN = "unknown"


class Device(BaseModel):
    """Device configuration for SSH connections"""
    id: str
    name: str
    hostname: str
    username: str
    port: int = 22
    cursor_agent_path: Optional[str] = None
    created_at: datetime
    last_seen: Optional[datetime] = None
    is_active: bool = True
    status: DeviceStatus = DeviceStatus.UNKNOWN
    
    class Config:
        use_enum_values = True


class DeviceCreate(BaseModel):
    """Request model for creating a device"""
    name: str = Field(..., min_length=1, max_length=100)
    hostname: str = Field(..., min_length=1, max_length=255)
    username: str = Field(..., min_length=1, max_length=100)
    port: int = Field(default=22, ge=1, le=65535)
    cursor_agent_path: Optional[str] = None


class DeviceUpdate(BaseModel):
    """Request model for updating a device"""
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    hostname: Optional[str] = Field(None, min_length=1, max_length=255)
    username: Optional[str] = Field(None, min_length=1, max_length=100)
    port: Optional[int] = Field(None, ge=1, le=65535)
    cursor_agent_path: Optional[str] = None
    is_active: Optional[bool] = None


class RemoteChat(BaseModel):
    """Remote chat metadata stored in local database"""
    chat_id: str
    device_id: str
    working_directory: str
    name: str = "Untitled"
    created_at: datetime
    last_updated_at: Optional[datetime] = None
    message_count: int = 0
    last_message_preview: Optional[str] = None


class RemoteChatCreate(BaseModel):
    """Request model for creating a remote chat"""
    device_id: str
    working_directory: str = Field(..., min_length=1)
    name: Optional[str] = None


class ChatLocation(str, Enum):
    """Chat location type"""
    LOCAL = "local"
    REMOTE = "remote"

