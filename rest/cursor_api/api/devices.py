"""Device management API endpoints"""

from typing import Optional
from fastapi import APIRouter, HTTPException, Query

from ..models.device import DeviceCreate, DeviceUpdate, RemoteChatCreate
from ..services import device_service
from ..services.ssh_agent_service import (
    verify_cursor_agent_installed,
    verify_remote_directory,
    list_remote_directory,
    create_remote_chat as ssh_create_remote_chat
)

router = APIRouter(prefix="/devices", tags=["devices"])


@router.post("")
def create_device(device_create: DeviceCreate):
    """
    Create a new device configuration
    
    **Example:**
    ```json
    {
      "name": "Production Server",
      "hostname": "prod.example.com",
      "username": "deploy",
      "port": 22,
      "cursor_agent_path": "~/.local/bin/cursor-agent"
    }
    ```
    """
    try:
        device = device_service.create_device(device_create)
        return {
            "status": "success",
            "device": device.dict()
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("")
def list_devices(include_inactive: bool = Query(False, description="Include inactive devices")):
    """
    List all configured devices
    
    Returns devices with their current status (online/offline/unknown)
    """
    devices = device_service.list_devices(include_inactive=include_inactive)
    return {
        "total": len(devices),
        "devices": [d.dict() for d in devices]
    }


@router.get("/{device_id}")
def get_device(device_id: str):
    """Get device details by ID"""
    device = device_service.get_device(device_id)
    if not device:
        raise HTTPException(status_code=404, detail="Device not found")
    
    return device.dict()


@router.put("/{device_id}")
def update_device(device_id: str, device_update: DeviceUpdate):
    """
    Update device configuration
    
    **Example:**
    ```json
    {
      "name": "Updated Server Name",
      "port": 2222
    }
    ```
    """
    device = device_service.update_device(device_id, device_update)
    if not device:
        raise HTTPException(status_code=404, detail="Device not found")
    
    return {
        "status": "success",
        "device": device.dict()
    }


@router.delete("/{device_id}")
def delete_device(device_id: str):
    """
    Delete a device configuration
    
    Note: This will also delete all remote chat associations for this device
    """
    deleted = device_service.delete_device(device_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Device not found")
    
    return {
        "status": "success",
        "message": "Device deleted successfully"
    }


@router.post("/{device_id}/test")
def test_device_connection(device_id: str):
    """
    Test SSH connection to a device
    
    Returns connection status and updates device's last_seen timestamp if successful
    """
    result = device_service.check_device_status(device_id)
    
    if not result.get("success") and "not found" in result.get("error", "").lower():
        raise HTTPException(status_code=404, detail="Device not found")
    
    return result


@router.post("/{device_id}/verify-agent")
def verify_agent_installed(device_id: str):
    """
    Verify that cursor-agent is installed on the remote device
    
    Returns installation status and version information
    """
    device = device_service.get_device(device_id)
    if not device:
        raise HTTPException(status_code=404, detail="Device not found")
    
    result = verify_cursor_agent_installed(device)
    return result


@router.post("/{device_id}/verify-directory")
def verify_directory(
    device_id: str,
    directory: str = Query(..., description="Remote directory path to verify")
):
    """
    Verify that a directory exists on the remote device
    
    **Usage:**
    ```
    POST /devices/{device_id}/verify-directory?directory=/opt/myapp
    ```
    """
    device = device_service.get_device(device_id)
    if not device:
        raise HTTPException(status_code=404, detail="Device not found")
    
    result = verify_remote_directory(device, directory)
    return result


@router.post("/{device_id}/browse")
def browse_directory(
    device_id: str,
    directory: str = Query(..., description="Remote directory path to browse")
):
    """
    Browse contents of a remote directory
    
    Returns list of files and subdirectories with permissions
    
    **Usage:**
    ```
    POST /devices/{device_id}/browse?directory=/opt/myapp
    ```
    """
    device = device_service.get_device(device_id)
    if not device:
        raise HTTPException(status_code=404, detail="Device not found")
    
    result = list_remote_directory(device, directory)
    return result


# Remote chat endpoints

@router.post("/{device_id}/create-chat")
def create_device_chat(device_id: str, chat_create: RemoteChatCreate):
    """
    Create a new chat on a remote device
    
    This will:
    1. Verify device exists and is accessible
    2. Verify working directory exists
    3. Execute cursor-agent create-chat on remote device
    4. Store chat association in local database
    
    **Example:**
    ```json
    {
      "device_id": "abc-123",
      "working_directory": "/opt/myapp",
      "name": "Backend Refactor"
    }
    ```
    """
    # Get device
    device = device_service.get_device(device_id)
    if not device:
        raise HTTPException(status_code=404, detail="Device not found")
    
    # Verify working directory exists
    dir_result = verify_remote_directory(device, chat_create.working_directory)
    if not dir_result["exists"]:
        raise HTTPException(
            status_code=400,
            detail=f"Working directory does not exist: {chat_create.working_directory}"
        )
    
    # Create chat on remote device
    result = ssh_create_remote_chat(device, chat_create.working_directory)
    if not result["success"]:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to create remote chat: {result['error']}"
        )
    
    # Store remote chat association
    remote_chat = device_service.create_remote_chat(chat_create, result["chat_id"])
    
    # Update device last_seen
    device_service.update_device_last_seen(device_id)
    
    return {
        "status": "success",
        "chat_id": remote_chat.chat_id,
        "device_id": remote_chat.device_id,
        "device_name": device.name,
        "working_directory": remote_chat.working_directory,
        "name": remote_chat.name
    }


@router.get("/chats/remote")
def list_remote_chats(device_id: Optional[str] = Query(None, description="Filter by device ID")):
    """
    List all remote chats, optionally filtered by device
    
    **Usage:**
    ```
    GET /devices/chats/remote
    GET /devices/chats/remote?device_id=abc-123
    ```
    """
    chats = device_service.list_remote_chats(device_id=device_id)
    
    # Enrich with device information
    chat_list = []
    for chat in chats:
        device = device_service.get_device(chat.device_id)
        chat_dict = chat.dict()
        chat_dict["device_name"] = device.name if device else "Unknown"
        chat_dict["device_status"] = device.status if device else "unknown"
        chat_list.append(chat_dict)
    
    return {
        "total": len(chat_list),
        "chats": chat_list
    }

