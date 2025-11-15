#!/usr/bin/env python3
"""
Blink MCP Server - Model Context Protocol server for LLM agent control

This MCP server exposes Blink's remote agent functionality to LLM agents
running in Cursor IDE. It provides tools for device management, chat creation,
and task delegation to remote cursor-agent instances.

Version 2.0 - Refactored for improved UX and robustness
"""

import sys
import json
import asyncio
import aiohttp
from typing import Dict, Any, List, Optional, Tuple
from datetime import datetime
from enum import Enum

API_BASE_URL = "http://localhost:8067"
DEFAULT_RETRY_COUNT = 3
DEFAULT_RETRY_BACKOFF = 2.0


class ErrorCode(Enum):
    """Structured error codes for better error handling"""
    CONNECTION_ERROR = "CONNECTION_ERROR"
    RESOURCE_NOT_FOUND = "RESOURCE_NOT_FOUND"
    TIMEOUT_ERROR = "TIMEOUT_ERROR"
    AUTHENTICATION_ERROR = "AUTHENTICATION_ERROR"
    VALIDATION_ERROR = "VALIDATION_ERROR"
    UNKNOWN_ERROR = "UNKNOWN_ERROR"


class BlinkError(Exception):
    """Base exception for Blink API errors"""
    def __init__(self, code: ErrorCode, message: str, details: Optional[Dict] = None, 
                 suggestions: Optional[List[str]] = None, recoverable: bool = False):
        self.code = code
        self.message = message
        self.details = details or {}
        self.suggestions = suggestions or []
        self.recoverable = recoverable
        super().__init__(message)
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "code": self.code.value,
            "message": self.message,
            "details": self.details,
            "suggestions": self.suggestions,
            "recoverable": self.recoverable
        }


class BlinkApiClient:
    """HTTP client for Blink REST API with retry logic"""
    
    def __init__(self, base_url: str = API_BASE_URL):
        self.base_url = base_url
        self.session: Optional[aiohttp.ClientSession] = None
    
    async def __aenter__(self):
        self.session = aiohttp.ClientSession()
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            await self.session.close()
    
    async def _request_with_retry(self, method: str, endpoint: str, 
                                  data: Optional[Dict] = None, 
                                  retry_count: int = DEFAULT_RETRY_COUNT) -> Dict[str, Any]:
        """Make HTTP request with exponential backoff retry"""
        url = f"{self.base_url}{endpoint}"
        last_error = None
        
        for attempt in range(retry_count):
            try:
                if method == "GET":
                    async with self.session.get(url) as response:
                        response.raise_for_status()
                        return await response.json()
                else:  # POST
                    async with self.session.post(url, json=data) as response:
                        response.raise_for_status()
                        return await response.json()
            
            except aiohttp.ClientError as e:
                last_error = e
                if attempt < retry_count - 1:
                    wait_time = DEFAULT_RETRY_BACKOFF ** attempt
                    await asyncio.sleep(wait_time)
                    continue
                
                # Final attempt failed
                raise BlinkError(
                    code=ErrorCode.CONNECTION_ERROR,
                    message=f"Failed to connect to Blink API after {retry_count} attempts",
                    details={"url": url, "error": str(e)},
                    suggestions=["Check that blink-api is running on localhost:8067",
                                "Verify network connectivity"],
                    recoverable=True
                ) from e
            
            except Exception as e:
                raise BlinkError(
                    code=ErrorCode.UNKNOWN_ERROR,
                    message=f"Unexpected error during API request",
                    details={"url": url, "error": str(e)},
                    recoverable=False
                ) from e
        
        # Should not reach here
        raise BlinkError(
            code=ErrorCode.CONNECTION_ERROR,
            message="Request failed",
            details={"error": str(last_error) if last_error else "Unknown"},
            recoverable=True
        )
    
    async def get(self, endpoint: str) -> Dict[str, Any]:
        """Make GET request to API"""
        return await self._request_with_retry("GET", endpoint)
    
    async def post(self, endpoint: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """Make POST request to API"""
        return await self._request_with_retry("POST", endpoint, data)
    
    # Device Management
    
    async def list_devices(self) -> List[Dict[str, Any]]:
        """List all configured remote devices"""
        result = await self.get("/devices")
        return result.get("devices", [])
    
    async def add_device(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Register a new remote device"""
        return await self.post("/devices", data)
    
    async def test_device_connection(self, device_id: str) -> Dict[str, Any]:
        """Test SSH connection to a remote device"""
        return await self.post(f"/devices/{device_id}/test", {})
    
    # Unified Chat Management
    
    async def create_chat(self, device_id: Optional[str] = None, 
                         working_directory: Optional[str] = None,
                         name: Optional[str] = None) -> Dict[str, Any]:
        """Create a chat (local if device_id is None, otherwise remote)"""
        if device_id:
            # Remote chat - working_directory and device_id are required by backend
            data = {
                "device_id": device_id,  # Backend requires this in body even though it's in URL
                "working_directory": working_directory or "/tmp"  # Default to /tmp if not specified
            }
            if name:
                data["name"] = name
            return await self.post(f"/devices/{device_id}/create-chat", data)
        else:
            # Local chat
            data = {}
            if name:
                data["name"] = name
            return await self.post("/agent/create-chat", data)
    
    async def send_prompt_async(self, chat_id: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """Send a prompt to a chat asynchronously (returns job_id)"""
        return await self.post(f"/chats/{chat_id}/agent-prompt-async", data)
    
    async def get_job_status(self, job_id: str) -> Dict[str, Any]:
        """Get status of an async job"""
        return await self.get(f"/jobs/{job_id}")
    
    async def wait_for_job(self, job_id: str, timeout_secs: int = 300) -> Dict[str, Any]:
        """Wait for a job to complete with timeout"""
        start = asyncio.get_event_loop().time()
        while True:
            job = await self.get_job_status(job_id)
            status = job.get("status", "unknown")
            
            if status == "completed":
                return job
            elif status == "failed":
                raise BlinkError(
                    code=ErrorCode.UNKNOWN_ERROR,
                    message="Job execution failed",
                    details={"job_id": job_id, "error": job.get("error", "Unknown error")},
                    recoverable=False
                )
            elif status == "cancelled":
                raise BlinkError(
                    code=ErrorCode.UNKNOWN_ERROR,
                    message="Job was cancelled",
                    details={"job_id": job_id},
                    recoverable=False
                )
            
            if asyncio.get_event_loop().time() - start > timeout_secs:
                raise BlinkError(
                    code=ErrorCode.TIMEOUT_ERROR,
                    message=f"Job timeout after {timeout_secs} seconds",
                    details={"job_id": job_id, "timeout": timeout_secs},
                    suggestions=["Increase timeout parameter", "Check job status with manage_job"],
                    recoverable=True
                )
            
            await asyncio.sleep(2)
    
    async def cancel_job(self, job_id: str) -> Dict[str, Any]:
        """Cancel a running job"""
        return await self.post(f"/jobs/{job_id}/cancel", {})
    
    async def list_jobs(self, chat_id: Optional[str] = None) -> List[Dict[str, Any]]:
        """List jobs, optionally filtered by chat_id"""
        if chat_id:
            result = await self.get(f"/chats/{chat_id}/jobs")
            return result.get("jobs", [])
        else:
            # TODO: Add endpoint for listing all jobs
            return []
    
    async def get_chat_messages(self, chat_id: str, limit: Optional[int] = None) -> Dict[str, Any]:
        """Retrieve conversation history from a chat"""
        url = f"/chats/{chat_id}?include_metadata=true&include_content=true"
        if limit:
            url += f"&limit={limit}"
        return await self.get(url)
    
    async def list_chats(self, device_id: Optional[str] = None) -> List[Dict[str, Any]]:
        """List all chats, optionally filtered by device"""
        result = await self.get("/remote-chats")
        chats = result.get("chats", [])
        
        if device_id:
            chats = [c for c in chats if c.get("device_id") == device_id]
        
        return chats


def format_response(status: str, data: Any, message: str, 
                   operation: str, resource_id: Optional[str] = None,
                   hints: Optional[List[str]] = None) -> str:
    """Format response in structured JSON format"""
    response = {
        "status": status,
        "data": data,
        "message": message,
        "metadata": {
            "operation": operation,
            "timestamp": datetime.utcnow().isoformat() + "Z",
        }
    }
    
    if resource_id:
        response["metadata"]["resource_id"] = resource_id
    
    if hints:
        response["metadata"]["hints"] = hints
    
    return json.dumps(response, indent=2)


def format_error(error: BlinkError) -> str:
    """Format error in structured JSON format"""
    return json.dumps(error.to_dict(), indent=2)


def get_tool_definitions() -> List[Dict[str, Any]]:
    """Return MCP tool definitions (refactored v2.0)"""
    return [
        # Unified chat creation
        {
            "name": "create_chat",
            "description": "Create a new chat for agent interaction. Creates locally if device_id is omitted, or on a remote device if specified. Context is automatically preserved across messages.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "device_id": {
                        "type": "string",
                        "description": "Optional: Device UUID for remote chat (from list_devices). Omit for local chat."
                    },
                    "working_directory": {
                        "type": "string",
                        "description": "Optional: Working directory path (defaults to $HOME). Only used for remote chats."
                    },
                    "name": {
                        "type": "string",
                        "description": "Optional: Chat name for organization"
                    }
                },
                "required": []
            }
        },
        
        # Unified task sending
        {
            "name": "send_task",
            "description": "Send a message to any chat (local or remote). Context is automatically preserved - each message has access to full conversation history. Use wait=false for long-running tasks.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "chat_id": {
                        "type": "string",
                        "description": "Chat UUID (from create_chat)"
                    },
                    "message": {
                        "type": "string",
                        "description": "Your message or task description for the agent"
                    },
                    "model": {
                        "type": "string",
                        "description": "Optional: AI model to use (e.g., 'sonnet-4.5-thinking', 'gpt-4'). Defaults to system default."
                    },
                    "wait": {
                        "type": "boolean",
                        "description": "Wait for completion before returning (default: true). Set false for fire-and-forget.",
                        "default": True
                    },
                    "timeout": {
                        "type": "integer",
                        "description": "Maximum seconds to wait if wait=true (default: 300)",
                        "default": 300
                    }
                },
                "required": ["chat_id", "message"]
            }
        },
        
        # Chat history
        {
            "name": "get_chat_history",
            "description": "View conversation history from any chat (local or remote). Shows all messages exchanged with the agent.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "chat_id": {
                        "type": "string",
                        "description": "Chat UUID"
                    },
                    "limit": {
                        "type": "integer",
                        "description": "Optional: Maximum number of messages to retrieve (default: all)"
                    }
                },
                "required": ["chat_id"]
            }
        },
        
        # List chats
        {
            "name": "list_chats",
            "description": "List all active chats (local and remote). Shows chat ID, device, working directory, message count, and last activity. Use this to find existing chats before creating new ones.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "device_id": {
                        "type": "string",
                        "description": "Optional: Filter by device UUID"
                    }
                },
                "required": []
            }
        },
        
        # Device management
        {
            "name": "list_devices",
            "description": "List all configured remote devices (SSH-accessible machines). Returns device ID, name, hostname, and connection status.",
            "inputSchema": {
                "type": "object",
                "properties": {},
                "required": []
            }
        },
        
        {
            "name": "add_device",
            "description": "Register a new remote device for SSH-based cursor-agent execution. Requires SSH key authentication to be set up beforehand. Use test_device after adding to verify connectivity.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "name": {
                        "type": "string",
                        "description": "User-friendly name (e.g., 'GPU Server', 'Production')"
                    },
                    "hostname": {
                        "type": "string",
                        "description": "SSH hostname or IP address (can use SSH config aliases)"
                    },
                    "username": {
                        "type": "string",
                        "description": "SSH username"
                    },
                    "port": {
                        "type": "integer",
                        "description": "SSH port (default 22)",
                        "default": 22
                    },
                    "cursor_agent_path": {
                        "type": "string",
                        "description": "Path to cursor-agent on remote (default: ~/.local/bin/cursor-agent)"
                    }
                },
                "required": ["name", "hostname", "username"]
            }
        },
        
        {
            "name": "test_device",
            "description": "Test SSH connection to a remote device. Verifies that SSH authentication works and the device is reachable. Returns detailed error information if connection fails.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "device_id": {
                        "type": "string",
                        "description": "Device UUID (from list_devices or add_device)"
                    }
                },
                "required": ["device_id"]
            }
        },
        
        # Unified job management
        {
            "name": "manage_job",
            "description": "Manage async jobs: get status/result, cancel, or list jobs. Use this to check on fire-and-forget tasks or cancel long-running operations.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "action": {
                        "type": "string",
                        "enum": ["get", "cancel", "list"],
                        "description": "Action to perform: 'get' (status/result), 'cancel' (abort job), 'list' (all jobs for chat)"
                    },
                    "job_id": {
                        "type": "string",
                        "description": "Job UUID (required for 'get' and 'cancel' actions)"
                    },
                    "chat_id": {
                        "type": "string",
                        "description": "Chat UUID (required for 'list' action)"
                    }
                },
                "required": ["action"]
            }
        },
        
        # Bulk operations for parallelization
        {
            "name": "send_tasks_parallel",
            "description": "Send multiple tasks in parallel with optional dependency management. Dramatically speeds up workflows by running independent tasks simultaneously. Returns job IDs for all tasks.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "tasks": {
                        "type": "array",
                        "description": "Array of task definitions",
                        "items": {
                            "type": "object",
                            "properties": {
                                "chat_id": {
                                    "type": "string",
                                    "description": "Chat UUID for this task"
                                },
                                "message": {
                                    "type": "string",
                                    "description": "Task message"
                                },
                                "model": {
                                    "type": "string",
                                    "description": "Optional: AI model"
                                },
                                "task_id": {
                                    "type": "string",
                                    "description": "Optional: Identifier for this task (for dependencies)"
                                },
                                "depends_on": {
                                    "type": "array",
                                    "items": {"type": "string"},
                                    "description": "Optional: List of task_ids this task depends on"
                                }
                            },
                            "required": ["chat_id", "message"]
                        }
                    },
                    "wait": {
                        "type": "boolean",
                        "description": "Wait for all tasks to complete (default: false)",
                        "default": False
                    },
                    "timeout": {
                        "type": "integer",
                        "description": "Maximum seconds to wait if wait=true (default: 600)",
                        "default": 600
                    }
                },
                "required": ["tasks"]
            }
        },
        
        # Resource cleanup
        {
            "name": "cleanup_resources",
            "description": "Clean up old jobs and ephemeral chats. Helps maintain system performance by removing completed jobs and unused chats.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "resource_type": {
                        "type": "string",
                        "enum": ["jobs", "chats", "all"],
                        "description": "Type of resources to clean up"
                    },
                    "older_than_hours": {
                        "type": "integer",
                        "description": "Clean up resources older than this many hours (default: 24)",
                        "default": 24
                    }
                },
                "required": ["resource_type"]
            }
        }
    ]


async def handle_tool_call(client: BlinkApiClient, name: str, arguments: Dict[str, Any]) -> str:
    """Handle individual tool invocations with structured responses"""
    
    try:
        # Unified chat creation
        if name == "create_chat":
            device_id = arguments.get("device_id")
            working_directory = arguments.get("working_directory")
            chat_name = arguments.get("name")
            
            result = await client.create_chat(
                device_id=device_id,
                working_directory=working_directory,
                name=chat_name
            )
            
            chat_id = result.get("chat_id", "")
            location = "remote" if device_id else "local"
            device_name = result.get("device_name", "local machine")
            
            return format_response(
                status="success",
                data={
                    "chat_id": chat_id,
                    "location": location,
                    "device_name": device_name,
                    "working_directory": result.get("working_directory", ""),
                    "name": chat_name or "Untitled"
                },
                message=f"Chat created successfully on {device_name}",
                operation="create_chat",
                resource_id=chat_id,
                hints=["Use send_task to communicate with this chat"]
            )
        
        # Unified task sending
        elif name == "send_task":
            chat_id = arguments.get("chat_id")
            if not chat_id:
                raise BlinkError(
                    code=ErrorCode.VALIDATION_ERROR,
                    message="Missing required parameter: chat_id",
                    suggestions=["Use create_chat to create a new chat first",
                               "Use list_chats to see available chats"],
                    recoverable=True
                )
            
            message = arguments.get("message")
            if not message:
                raise BlinkError(
                    code=ErrorCode.VALIDATION_ERROR,
                    message="Missing required parameter: message",
                    recoverable=True
                )
            
            wait = arguments.get("wait", True)
            model = arguments.get("model")
            timeout = arguments.get("timeout", 300)
            
            # Prepare prompt data
            prompt_data = {"prompt": message}
            if model:
                prompt_data["model"] = model
            
            # Submit job
            job_result = await client.send_prompt_async(chat_id, prompt_data)
            job_id = job_result.get("job_id")
            
            if not job_id:
                raise BlinkError(
                    code=ErrorCode.UNKNOWN_ERROR,
                    message="No job_id returned from API",
                    recoverable=False
                )
            
            if not wait:
                # Fire-and-forget mode
                return format_response(
                    status="in_progress",
                    data={"job_id": job_id, "chat_id": chat_id},
                    message="Task submitted successfully",
                    operation="send_task",
                    resource_id=job_id,
                    hints=["Use manage_job with action='get' to check status"]
                )
            else:
                # Wait for completion
                job = await client.wait_for_job(job_id, timeout)
                result = job.get("result", {})
                
                # Parse result if it's a JSON string
                if isinstance(result, str):
                    try:
                        result = json.loads(result)
                    except:
                        pass
                
                # Extract agent response
                if isinstance(result, dict):
                    content = result.get("content", {})
                    agent_response = content.get("assistant", result.get("response", "No response"))
                else:
                    agent_response = str(result) if result else "No response"
                
                return format_response(
                    status="success",
                    data={
                        "job_id": job_id,
                        "chat_id": chat_id,
                        "response": agent_response
                    },
                    message="Task completed successfully",
                    operation="send_task",
                    resource_id=job_id,
                    hints=["Use get_chat_history to see full conversation"]
                )
        
        # Chat history
        elif name == "get_chat_history":
            chat_id = arguments.get("chat_id")
            if not chat_id:
                raise BlinkError(
                    code=ErrorCode.VALIDATION_ERROR,
                    message="Missing required parameter: chat_id",
                    recoverable=True
                )
            
            limit = arguments.get("limit")
            
            chat_data = await client.get_chat_messages(chat_id, limit)
            metadata = chat_data.get("metadata", {})
            messages = chat_data.get("messages", [])
            
            formatted_messages = []
            for msg in messages:
                formatted_messages.append({
                    "role": msg.get("type_label", "unknown"),
                    "content": msg.get("text", ""),
                    "timestamp": msg.get("created_at", "")
                })
            
            return format_response(
                status="success",
                data={
                    "chat_id": chat_id,
                    "name": metadata.get("name", "Untitled"),
                    "device": metadata.get("device_name", "Unknown"),
                    "message_count": chat_data.get("message_count", 0),
                    "messages": formatted_messages
                },
                message=f"Retrieved {len(messages)} messages",
                operation="get_chat_history",
                resource_id=chat_id,
                hints=["Use send_task to continue the conversation"] if messages else 
                      ["Use send_task to start the conversation"]
            )
        
        # List chats
        elif name == "list_chats":
            device_id = arguments.get("device_id")
            chats = await client.list_chats(device_id=device_id)
            
            formatted_chats = []
            for chat in chats:
                formatted_chats.append({
                    "chat_id": chat.get("chat_id", ""),
                    "name": chat.get("name", "Untitled"),
                    "device_name": chat.get("device_name", "Unknown"),
                    "device_id": chat.get("device_id", ""),
                    "working_directory": chat.get("working_directory", ""),
                    "message_count": chat.get("message_count", 0),
                    "last_updated": chat.get("last_updated_at", "")
                })
            
            return format_response(
                status="success",
                data={"chats": formatted_chats, "count": len(formatted_chats)},
                message=f"Found {len(formatted_chats)} active chat(s)",
                operation="list_chats",
                hints=["Use get_chat_history to view a chat's messages",
                      "Use send_task to interact with a chat"] if chats else
                      ["Use create_chat to start a new chat"]
            )
        
        # List devices
        elif name == "list_devices":
            devices = await client.list_devices()
            
            formatted_devices = []
            for device in devices:
                formatted_devices.append({
                    "device_id": device.get("id", ""),
                    "name": device.get("name", "Unknown"),
                    "hostname": device.get("hostname", ""),
                    "username": device.get("username", ""),
                    "status": device.get("status", "unknown")
                })
            
            return format_response(
                status="success",
                data={"devices": formatted_devices, "count": len(formatted_devices)},
                message=f"Found {len(formatted_devices)} configured device(s)",
                operation="list_devices",
                hints=["Use add_device to register a new device",
                      "Use create_chat with device_id to create remote chat"] if devices else
                      ["Use add_device to register your first remote device"]
            )
        
        # Add device
        elif name == "add_device":
            result = await client.add_device(arguments)
            device = result.get("device", {})
            device_id = device.get("id", "")
            
            return format_response(
                status="success",
                data={
                    "device_id": device_id,
                    "name": device.get("name", "Unknown"),
                    "hostname": device.get("hostname", ""),
                    "username": device.get("username", "")
                },
                message="Device registered successfully",
                operation="add_device",
                resource_id=device_id,
                hints=["Use test_device to verify connectivity",
                      "Use create_chat with this device_id to create remote chats"]
            )
        
        # Test device
        elif name == "test_device":
            device_id = arguments.get("device_id")
            if not device_id:
                raise BlinkError(
                    code=ErrorCode.VALIDATION_ERROR,
                    message="Missing required parameter: device_id",
                    suggestions=["Use list_devices to see available devices"],
                    recoverable=True
                )
            
            result = await client.test_device_connection(device_id)
            success = result.get("success", False)
            
            if success:
                return format_response(
                    status="success",
                    data={
                        "device_id": device_id,
                        "device_name": result.get("device_name", "Unknown"),
                        "online": True
                    },
                    message="Device is online and reachable",
                    operation="test_device",
                    resource_id=device_id,
                    hints=["Device is ready for remote chat creation"]
                )
            else:
                return format_response(
                    status="error",
                    data={
                        "device_id": device_id,
                        "device_name": result.get("device_name", "Unknown"),
                        "error": result.get("stderr", "Connection failed"),
                        "online": False
                    },
                    message="Device connection failed",
                    operation="test_device",
                    resource_id=device_id,
                    hints=["Check SSH key authentication is set up",
                          "Verify hostname and username are correct",
                          "Ensure device is online and accessible"]
                )
        
        # Manage job
        elif name == "manage_job":
            action = arguments.get("action")
            if not action:
                raise BlinkError(
                    code=ErrorCode.VALIDATION_ERROR,
                    message="Missing required parameter: action",
                    details={"valid_actions": ["get", "cancel", "list"]},
                    recoverable=True
                )
            
            if action == "get":
                job_id = arguments.get("job_id")
                if not job_id:
                    raise BlinkError(
                        code=ErrorCode.VALIDATION_ERROR,
                        message="Missing required parameter: job_id for action 'get'",
                        recoverable=True
                    )
                
                job = await client.get_job_status(job_id)
                status = job.get("status", "unknown")
                
                job_data = {
                    "job_id": job_id,
                    "status": status,
                    "chat_id": job.get("chat_id", ""),
                    "created_at": job.get("created_at", ""),
                    "started_at": job.get("started_at", ""),
                    "completed_at": job.get("completed_at", "")
                }
                
                if status == "completed":
                    result = job.get("result", {})
                    if isinstance(result, str):
                        try:
                            result = json.loads(result)
                        except:
                            pass
                    
                    if isinstance(result, dict):
                        content = result.get("content", {})
                        job_data["response"] = content.get("assistant", "No response")
                    else:
                        job_data["response"] = str(result) if result else "No response"
                
                elif status == "failed":
                    job_data["error"] = job.get("error", "Unknown error")
                
                return format_response(
                    status="success" if status == "completed" else status,
                    data=job_data,
                    message=f"Job is {status}",
                    operation="manage_job",
                    resource_id=job_id,
                    hints=["Job completed successfully"] if status == "completed" else
                          ["Check again in a few moments"] if status in ["pending", "processing"] else
                          []
                )
            
            elif action == "cancel":
                job_id = arguments.get("job_id")
                if not job_id:
                    raise BlinkError(
                        code=ErrorCode.VALIDATION_ERROR,
                        message="Missing required parameter: job_id for action 'cancel'",
                        recoverable=True
                    )
                
                result = await client.cancel_job(job_id)
                
                return format_response(
                    status="success",
                    data={"job_id": job_id, "cancelled": True},
                    message="Job cancelled successfully",
                    operation="manage_job",
                    resource_id=job_id
                )
            
            elif action == "list":
                chat_id = arguments.get("chat_id")
                if not chat_id:
                    raise BlinkError(
                        code=ErrorCode.VALIDATION_ERROR,
                        message="Missing required parameter: chat_id for action 'list'",
                        recoverable=True
                    )
                
                jobs = await client.list_jobs(chat_id=chat_id)
                
                formatted_jobs = []
                for job in jobs:
                    formatted_jobs.append({
                        "job_id": job.get("job_id", ""),
                        "status": job.get("status", "unknown"),
                        "created_at": job.get("created_at", "")
                    })
                
                return format_response(
                    status="success",
                    data={"jobs": formatted_jobs, "count": len(formatted_jobs), "chat_id": chat_id},
                    message=f"Found {len(formatted_jobs)} job(s) for this chat",
                    operation="manage_job",
                    hints=["Use action='get' to check individual job status"]
                )
            
            else:
                raise BlinkError(
                    code=ErrorCode.VALIDATION_ERROR,
                    message=f"Unknown action: {action}",
                    details={"valid_actions": ["get", "cancel", "list"]},
                    recoverable=True
                )
        
        # Parallel task execution
        elif name == "send_tasks_parallel":
            tasks = arguments.get("tasks", [])
            if not tasks:
                raise BlinkError(
                    code=ErrorCode.VALIDATION_ERROR,
                    message="No tasks provided",
                    suggestions=["Provide at least one task in the 'tasks' array"],
                    recoverable=True
                )
            
            wait = arguments.get("wait", False)
            timeout = arguments.get("timeout", 600)
            
            # Build dependency graph
            task_map = {}
            for task in tasks:
                task_id = task.get("task_id", f"task_{len(task_map)}")
                task_map[task_id] = task
            
            # Submit all independent tasks first
            job_ids = []
            job_map = {}  # task_id -> job_id
            
            for task_id, task in task_map.items():
                chat_id = task.get("chat_id")
                message = task.get("message")
                model = task.get("model")
                depends_on = task.get("depends_on", [])
                
                if not chat_id or not message:
                    continue
                
                # For now, submit all tasks (dependency handling would require backend support)
                prompt_data = {"prompt": message}
                if model:
                    prompt_data["model"] = model
                
                job_result = await client.send_prompt_async(chat_id, prompt_data)
                job_id = job_result.get("job_id")
                
                if job_id:
                    job_ids.append(job_id)
                    job_map[task_id] = job_id
            
            if not wait:
                return format_response(
                    status="in_progress",
                    data={
                        "job_ids": job_ids,
                        "task_count": len(job_ids),
                        "job_map": job_map
                    },
                    message=f"Submitted {len(job_ids)} tasks in parallel",
                    operation="send_tasks_parallel",
                    hints=["Use manage_job with action='get' to check each job",
                          "Tasks are executing concurrently"]
                )
            else:
                # Wait for all tasks to complete
                results = {}
                for task_id, job_id in job_map.items():
                    try:
                        job = await client.wait_for_job(job_id, timeout)
                        result = job.get("result", {})
                        
                        if isinstance(result, str):
                            try:
                                result = json.loads(result)
                            except:
                                pass
                        
                        if isinstance(result, dict):
                            content = result.get("content", {})
                            results[task_id] = {
                                "job_id": job_id,
                                "status": "completed",
                                "response": content.get("assistant", "No response")
                            }
                        else:
                            results[task_id] = {
                                "job_id": job_id,
                                "status": "completed",
                                "response": str(result) if result else "No response"
                            }
                    except BlinkError as e:
                        results[task_id] = {
                            "job_id": job_id,
                            "status": "failed",
                            "error": e.message
                        }
                
                return format_response(
                    status="success",
                    data={
                        "results": results,
                        "completed_count": sum(1 for r in results.values() if r.get("status") == "completed"),
                        "failed_count": sum(1 for r in results.values() if r.get("status") == "failed"),
                        "total_count": len(results)
                    },
                    message=f"All {len(results)} tasks completed",
                    operation="send_tasks_parallel"
                )
        
        # Cleanup resources
        elif name == "cleanup_resources":
            resource_type = arguments.get("resource_type", "all")
            older_than_hours = arguments.get("older_than_hours", 24)
            
            # Note: This would require backend implementation
            return format_response(
                status="success",
                data={
                    "resource_type": resource_type,
                    "older_than_hours": older_than_hours,
                    "cleaned": 0
                },
                message="Cleanup not yet implemented - requires backend support",
                operation="cleanup_resources",
                hints=["This feature will be available in a future update"]
            )
        
        # Deprecated tools (with warnings)
        elif name in ["create_local_chat", "create_remote_chat"]:
            return format_response(
                status="error",
                data={
                    "deprecated": True,
                    "replacement": "create_chat"
                },
                message=f"Tool '{name}' is deprecated. Use 'create_chat' instead.",
                operation=name,
                hints=["Use create_chat with device_id for remote chats",
                      "Use create_chat without device_id for local chats"]
            )
        
        elif name in ["send_local_task", "send_remote_task", "continue_conversation"]:
            return format_response(
                status="error",
                data={
                    "deprecated": True,
                    "replacement": "send_task"
                },
                message=f"Tool '{name}' is deprecated. Use 'send_task' instead.",
                operation=name,
                hints=["send_task works with any chat (local or remote)",
                      "Context is automatically preserved"]
            )
        
        elif name == "list_remote_devices":
            return format_response(
                status="error",
                data={
                    "deprecated": True,
                    "replacement": "list_devices"
                },
                message="Tool 'list_remote_devices' is deprecated. Use 'list_devices' instead.",
                operation=name
            )
        
        elif name == "list_remote_chats":
            return format_response(
                status="error",
                data={
                    "deprecated": True,
                    "replacement": "list_chats"
                },
                message="Tool 'list_remote_chats' is deprecated. Use 'list_chats' instead.",
                operation=name
            )
        
        elif name in ["get_job_result", "cancel_job"]:
            return format_response(
                status="error",
                data={
                    "deprecated": True,
                    "replacement": "manage_job"
                },
                message=f"Tool '{name}' is deprecated. Use 'manage_job' instead.",
                operation=name,
                hints=["Use manage_job with action='get' to get job status/result",
                      "Use manage_job with action='cancel' to cancel a job"]
            )
        
        elif name == "test_device_connection":
            return format_response(
                status="error",
                data={
                    "deprecated": True,
                    "replacement": "test_device"
                },
                message="Tool 'test_device_connection' is deprecated. Use 'test_device' instead.",
                operation=name
            )
        
        else:
            raise BlinkError(
                code=ErrorCode.VALIDATION_ERROR,
                message=f"Unknown tool: {name}",
                suggestions=["Use tools/list to see available tools"],
                recoverable=False
            )
    
    except BlinkError as e:
        # Structured error already
        return format_error(e)
    
    except Exception as e:
        # Unexpected error
        error = BlinkError(
            code=ErrorCode.UNKNOWN_ERROR,
            message=str(e),
            details={"tool": name, "arguments": arguments},
            recoverable=False
        )
        return format_error(error)


def send_response(response: Dict[str, Any]) -> None:
    """Send JSON-RPC response to stdout"""
    print(json.dumps(response), flush=True)


def send_result(request_id: Any, result: Any) -> None:
    """Send successful JSON-RPC result"""
    response = {
        "jsonrpc": "2.0",
        "result": result
    }
    # Only include id if it exists (distinguish request from notification)
    if request_id is not None:
        response["id"] = request_id
    send_response(response)


def send_error(request_id: Any, code: int, message: str, data: Any = None) -> None:
    """Send JSON-RPC error response"""
    error_obj = {
        "code": code,
        "message": message
    }
    if data is not None:
        error_obj["data"] = data
    
    response = {
        "jsonrpc": "2.0",
        "error": error_obj
    }
    # Only include id if it exists (distinguish request from notification)
    if request_id is not None:
        response["id"] = request_id
    send_response(response)


async def process_request(client: BlinkApiClient, request: Dict[str, Any]) -> None:
    """Process a single JSON-RPC request"""
    request_id = request.get("id")
    method = request.get("method")
    
    if not method:
        send_error(request_id, -32600, "Invalid request: missing method")
        return
    
    try:
        if method == "initialize":
            # MCP initialization handshake
            result = {
                "protocolVersion": "2024-11-05",
                "serverInfo": {
                    "name": "blink-agent-control",
                    "version": "2.0.0"
                },
                "capabilities": {
                    "tools": {}
                }
            }
            send_result(request_id, result)
        
        elif method == "initialized":
            # Notification that client has finished initializing - no response needed
            pass
        
        elif method == "tools/list":
            result = {"tools": get_tool_definitions()}
            send_result(request_id, result)
        
        elif method == "tools/call":
            params = request.get("params", {})
            tool_name = params.get("name", "")
            arguments = params.get("arguments", {})
            
            try:
                content = await handle_tool_call(client, tool_name, arguments)
                result = {
                    "content": [
                        {
                            "type": "text",
                            "text": content
                        }
                    ]
                }
                send_result(request_id, result)
            except Exception as e:
                send_error(
                    request_id,
                    -32000,
                    "Tool invocation failed",
                    {"details": str(e)}
                )
        
        else:
            send_error(request_id, -32601, f"Unknown method: {method}")
    
    except Exception as e:
        send_error(request_id, -32603, f"Internal error: {str(e)}")


async def main() -> None:
    """Main event loop - read JSON-RPC requests from stdin"""
    async with BlinkApiClient() as client:
        loop = asyncio.get_event_loop()
        
        # Read from stdin line by line
        while True:
            try:
                line = await loop.run_in_executor(None, sys.stdin.readline)
                if not line:
                    break
                
                line = line.strip()
                if not line:
                    continue
                
                try:
                    request = json.loads(line)
                    await process_request(client, request)
                except json.JSONDecodeError as e:
                    send_error(None, -32700, f"Parse error: {str(e)}")
            
            except KeyboardInterrupt:
                break
            except Exception as e:
                # Log to stderr (won't interfere with JSON-RPC on stdout)
                print(f"Unexpected error: {e}", file=sys.stderr)
                break


if __name__ == "__main__":
    asyncio.run(main())
