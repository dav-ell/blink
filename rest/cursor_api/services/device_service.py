"""Device and remote chat management service"""

import uuid
import sqlite3
from datetime import datetime, timezone
from typing import List, Optional, Dict, Any

from ..database.device_db import get_device_db_connection
from ..models.device import (
    Device, DeviceCreate, DeviceUpdate, DeviceStatus,
    RemoteChat, RemoteChatCreate
)
from .ssh_agent_service import test_ssh_connection, verify_cursor_agent_installed


def create_device(device_create: DeviceCreate) -> Device:
    """Create a new device configuration
    
    Args:
        device_create: Device creation data
        
    Returns:
        Created device
    """
    conn = get_device_db_connection()
    cursor = conn.cursor()
    
    device_id = str(uuid.uuid4())
    now_ms = int(datetime.now(timezone.utc).timestamp() * 1000)
    
    cursor.execute("""
        INSERT INTO devices (id, name, hostname, username, port, cursor_agent_path, created_at, is_active)
        VALUES (?, ?, ?, ?, ?, ?, ?, 1)
    """, (
        device_id,
        device_create.name,
        device_create.hostname,
        device_create.username,
        device_create.port,
        device_create.cursor_agent_path,
        now_ms
    ))
    
    conn.commit()
    conn.close()
    
    return Device(
        id=device_id,
        name=device_create.name,
        hostname=device_create.hostname,
        username=device_create.username,
        port=device_create.port,
        cursor_agent_path=device_create.cursor_agent_path,
        created_at=datetime.fromtimestamp(now_ms / 1000, tz=timezone.utc),
        is_active=True,
        status=DeviceStatus.UNKNOWN
    )


def get_device(device_id: str) -> Optional[Device]:
    """Get device by ID
    
    Args:
        device_id: Device ID
        
    Returns:
        Device or None if not found
    """
    conn = get_device_db_connection()
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT id, name, hostname, username, port, cursor_agent_path, 
               created_at, last_seen, is_active
        FROM devices
        WHERE id = ?
    """, (device_id,))
    
    row = cursor.fetchone()
    conn.close()
    
    if not row:
        return None
    
    # Determine status based on last_seen
    status = DeviceStatus.UNKNOWN
    if row[7]:  # last_seen
        last_seen_dt = datetime.fromtimestamp(row[7] / 1000, tz=timezone.utc)
        minutes_ago = (datetime.now(timezone.utc) - last_seen_dt).total_seconds() / 60
        if minutes_ago < 5:
            status = DeviceStatus.ONLINE
        elif minutes_ago < 60:
            status = DeviceStatus.UNKNOWN
        else:
            status = DeviceStatus.OFFLINE
    
    return Device(
        id=row[0],
        name=row[1],
        hostname=row[2],
        username=row[3],
        port=row[4],
        cursor_agent_path=row[5],
        created_at=datetime.fromtimestamp(row[6] / 1000, tz=timezone.utc),
        last_seen=datetime.fromtimestamp(row[7] / 1000, tz=timezone.utc) if row[7] else None,
        is_active=bool(row[8]),
        status=status
    )


def list_devices(include_inactive: bool = False) -> List[Device]:
    """List all devices
    
    Args:
        include_inactive: Whether to include inactive devices
        
    Returns:
        List of devices
    """
    conn = get_device_db_connection()
    cursor = conn.cursor()
    
    if include_inactive:
        cursor.execute("""
            SELECT id, name, hostname, username, port, cursor_agent_path,
                   created_at, last_seen, is_active
            FROM devices
            ORDER BY name
        """)
    else:
        cursor.execute("""
            SELECT id, name, hostname, username, port, cursor_agent_path,
                   created_at, last_seen, is_active
            FROM devices
            WHERE is_active = 1
            ORDER BY name
        """)
    
    devices = []
    for row in cursor.fetchall():
        # Determine status
        status = DeviceStatus.UNKNOWN
        if row[7]:  # last_seen
            last_seen_dt = datetime.fromtimestamp(row[7] / 1000, tz=timezone.utc)
            minutes_ago = (datetime.now(timezone.utc) - last_seen_dt).total_seconds() / 60
            if minutes_ago < 5:
                status = DeviceStatus.ONLINE
            elif minutes_ago < 60:
                status = DeviceStatus.UNKNOWN
            else:
                status = DeviceStatus.OFFLINE
        
        devices.append(Device(
            id=row[0],
            name=row[1],
            hostname=row[2],
            username=row[3],
            port=row[4],
            cursor_agent_path=row[5],
            created_at=datetime.fromtimestamp(row[6] / 1000, tz=timezone.utc),
            last_seen=datetime.fromtimestamp(row[7] / 1000, tz=timezone.utc) if row[7] else None,
            is_active=bool(row[8]),
            status=status
        ))
    
    conn.close()
    return devices


def update_device(device_id: str, device_update: DeviceUpdate) -> Optional[Device]:
    """Update device configuration
    
    Args:
        device_id: Device ID
        device_update: Update data
        
    Returns:
        Updated device or None if not found
    """
    conn = get_device_db_connection()
    cursor = conn.cursor()
    
    # Check if device exists
    cursor.execute("SELECT id FROM devices WHERE id = ?", (device_id,))
    if not cursor.fetchone():
        conn.close()
        return None
    
    # Build update query dynamically
    update_fields = []
    values = []
    
    if device_update.name is not None:
        update_fields.append("name = ?")
        values.append(device_update.name)
    
    if device_update.hostname is not None:
        update_fields.append("hostname = ?")
        values.append(device_update.hostname)
    
    if device_update.username is not None:
        update_fields.append("username = ?")
        values.append(device_update.username)
    
    if device_update.port is not None:
        update_fields.append("port = ?")
        values.append(device_update.port)
    
    if device_update.cursor_agent_path is not None:
        update_fields.append("cursor_agent_path = ?")
        values.append(device_update.cursor_agent_path)
    
    if device_update.is_active is not None:
        update_fields.append("is_active = ?")
        values.append(1 if device_update.is_active else 0)
    
    if update_fields:
        values.append(device_id)
        query = f"UPDATE devices SET {', '.join(update_fields)} WHERE id = ?"
        cursor.execute(query, values)
        conn.commit()
    
    conn.close()
    
    return get_device(device_id)


def delete_device(device_id: str) -> bool:
    """Delete a device (and its remote chats)
    
    Args:
        device_id: Device ID
        
    Returns:
        True if deleted, False if not found
    """
    conn = get_device_db_connection()
    cursor = conn.cursor()
    
    cursor.execute("DELETE FROM devices WHERE id = ?", (device_id,))
    deleted = cursor.rowcount > 0
    
    conn.commit()
    conn.close()
    
    return deleted


def update_device_last_seen(device_id: str) -> None:
    """Update device last_seen timestamp
    
    Args:
        device_id: Device ID
    """
    conn = get_device_db_connection()
    cursor = conn.cursor()
    
    now_ms = int(datetime.now(timezone.utc).timestamp() * 1000)
    cursor.execute("""
        UPDATE devices
        SET last_seen = ?
        WHERE id = ?
    """, (now_ms, device_id))
    
    conn.commit()
    conn.close()


def check_device_status(device_id: str) -> Dict[str, Any]:
    """Check device status and update last_seen if successful
    
    Args:
        device_id: Device ID
        
    Returns:
        Status information
    """
    device = get_device(device_id)
    if not device:
        return {"success": False, "error": "Device not found"}
    
    # Test SSH connection
    result = test_ssh_connection(device)
    
    # Update last_seen if successful
    if result["success"]:
        update_device_last_seen(device_id)
        device = get_device(device_id)  # Refresh to get updated status
    
    return {
        "success": result["success"],
        "status": device.status if device else DeviceStatus.UNKNOWN,
        "message": result["message"],
        "tested_at": result["tested_at"]
    }


# Remote chat management

def create_remote_chat(chat_create: RemoteChatCreate, chat_id: str) -> RemoteChat:
    """Create a remote chat record
    
    Args:
        chat_create: Remote chat creation data
        chat_id: Chat ID from cursor-agent create-chat
        
    Returns:
        Created remote chat
    """
    conn = get_device_db_connection()
    cursor = conn.cursor()
    
    now_ms = int(datetime.now(timezone.utc).timestamp() * 1000)
    name = chat_create.name or "Untitled"
    
    cursor.execute("""
        INSERT INTO remote_chats 
        (chat_id, device_id, working_directory, name, created_at, message_count)
        VALUES (?, ?, ?, ?, ?, 0)
    """, (
        chat_id,
        chat_create.device_id,
        chat_create.working_directory,
        name,
        now_ms
    ))
    
    conn.commit()
    conn.close()
    
    return RemoteChat(
        chat_id=chat_id,
        device_id=chat_create.device_id,
        working_directory=chat_create.working_directory,
        name=name,
        created_at=datetime.fromtimestamp(now_ms / 1000, tz=timezone.utc),
        message_count=0
    )


def get_remote_chat(chat_id: str) -> Optional[RemoteChat]:
    """Get remote chat by chat ID
    
    Args:
        chat_id: Chat ID
        
    Returns:
        Remote chat or None if not found
    """
    conn = get_device_db_connection()
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT chat_id, device_id, working_directory, name, created_at,
               last_updated_at, message_count, last_message_preview
        FROM remote_chats
        WHERE chat_id = ?
    """, (chat_id,))
    
    row = cursor.fetchone()
    conn.close()
    
    if not row:
        return None
    
    return RemoteChat(
        chat_id=row[0],
        device_id=row[1],
        working_directory=row[2],
        name=row[3],
        created_at=datetime.fromtimestamp(row[4] / 1000, tz=timezone.utc),
        last_updated_at=datetime.fromtimestamp(row[5] / 1000, tz=timezone.utc) if row[5] else None,
        message_count=row[6],
        last_message_preview=row[7]
    )


def list_remote_chats(device_id: Optional[str] = None) -> List[RemoteChat]:
    """List remote chats, optionally filtered by device
    
    Args:
        device_id: Optional device ID to filter by
        
    Returns:
        List of remote chats
    """
    conn = get_device_db_connection()
    cursor = conn.cursor()
    
    if device_id:
        cursor.execute("""
            SELECT chat_id, device_id, working_directory, name, created_at,
                   last_updated_at, message_count, last_message_preview
            FROM remote_chats
            WHERE device_id = ?
            ORDER BY last_updated_at DESC, created_at DESC
        """, (device_id,))
    else:
        cursor.execute("""
            SELECT chat_id, device_id, working_directory, name, created_at,
                   last_updated_at, message_count, last_message_preview
            FROM remote_chats
            ORDER BY last_updated_at DESC, created_at DESC
        """)
    
    chats = []
    for row in cursor.fetchall():
        chats.append(RemoteChat(
            chat_id=row[0],
            device_id=row[1],
            working_directory=row[2],
            name=row[3],
            created_at=datetime.fromtimestamp(row[4] / 1000, tz=timezone.utc),
            last_updated_at=datetime.fromtimestamp(row[5] / 1000, tz=timezone.utc) if row[5] else None,
            message_count=row[6],
            last_message_preview=row[7]
        ))
    
    conn.close()
    return chats


def update_remote_chat_metadata(
    chat_id: str,
    name: Optional[str] = None,
    message_count_delta: int = 0,
    last_message_preview: Optional[str] = None
) -> None:
    """Update remote chat metadata after message exchange
    
    Args:
        chat_id: Chat ID
        name: Optional new name
        message_count_delta: Number to add to message count (usually 2: user + assistant)
        last_message_preview: Preview of last message
    """
    conn = get_device_db_connection()
    cursor = conn.cursor()
    
    now_ms = int(datetime.now(timezone.utc).timestamp() * 1000)
    
    # Build update query
    update_parts = ["last_updated_at = ?"]
    values = [now_ms]
    
    if name is not None:
        update_parts.append("name = ?")
        values.append(name)
    
    if message_count_delta != 0:
        update_parts.append("message_count = message_count + ?")
        values.append(message_count_delta)
    
    if last_message_preview is not None:
        update_parts.append("last_message_preview = ?")
        values.append(last_message_preview)
    
    values.append(chat_id)
    
    query = f"UPDATE remote_chats SET {', '.join(update_parts)} WHERE chat_id = ?"
    cursor.execute(query, values)
    
    conn.commit()
    conn.close()


def delete_remote_chat(chat_id: str) -> bool:
    """Delete a remote chat record
    
    Args:
        chat_id: Chat ID
        
    Returns:
        True if deleted, False if not found
    """
    conn = get_device_db_connection()
    cursor = conn.cursor()
    
    cursor.execute("DELETE FROM remote_chats WHERE chat_id = ?", (chat_id,))
    deleted = cursor.rowcount > 0
    
    conn.commit()
    conn.close()
    
    return deleted

