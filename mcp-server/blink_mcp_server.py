#!/usr/bin/env python3
"""
Blink MCP Server - Model Context Protocol server for LLM agent control

This MCP server exposes Blink's remote agent functionality to LLM agents
running in Cursor IDE. It provides tools for device management, chat creation,
and task delegation to remote cursor-agent instances.
"""

import sys
import json
import asyncio
import aiohttp
from typing import Dict, Any, List, Optional

API_BASE_URL = "http://localhost:8067"


class BlinkApiClient:
    """HTTP client for Blink REST API"""
    
    def __init__(self, base_url: str = API_BASE_URL):
        self.base_url = base_url
        self.session: Optional[aiohttp.ClientSession] = None
    
    async def __aenter__(self):
        self.session = aiohttp.ClientSession()
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            await self.session.close()
    
    async def get(self, endpoint: str) -> Dict[str, Any]:
        """Make GET request to API"""
        url = f"{self.base_url}{endpoint}"
        async with self.session.get(url) as response:
            response.raise_for_status()
            return await response.json()
    
    async def post(self, endpoint: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """Make POST request to API"""
        url = f"{self.base_url}{endpoint}"
        async with self.session.post(url, json=data) as response:
            response.raise_for_status()
            return await response.json()
    
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
    
    # Chat Management
    
    async def create_local_chat(self, name: Optional[str] = None) -> Dict[str, Any]:
        """Create a new local cursor-agent chat"""
        data = {}
        if name:
            data["name"] = name
        return await self.post("/agent/create-chat", data)
    
    async def create_remote_chat(self, device_id: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """Create a new chat on a remote device"""
        return await self.post(f"/devices/{device_id}/create-chat", data)
    
    async def send_prompt_sync(self, chat_id: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """Send a prompt to a chat synchronously (blocks until complete)"""
        return await self.post(f"/chats/{chat_id}/agent-prompt", data)
    
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
                raise Exception(f"Job failed: {job.get('error', 'Unknown error')}")
            elif status == "cancelled":
                raise Exception("Job was cancelled")
            
            if asyncio.get_event_loop().time() - start > timeout_secs:
                raise Exception(f"Job timeout after {timeout_secs} seconds")
            
            await asyncio.sleep(2)
    
    # Context Management
    
    async def get_chat_messages(self, chat_id: str, limit: Optional[int] = None) -> Dict[str, Any]:
        """Retrieve conversation history from a chat"""
        url = f"/chats/{chat_id}?include_metadata=true&include_content=true"
        if limit:
            url += f"&limit={limit}"
        return await self.get(url)
    
    async def list_remote_chats(self) -> List[Dict[str, Any]]:
        """List all active remote chat sessions"""
        result = await self.get("/remote-chats")
        return result.get("chats", [])


def get_tool_definitions() -> List[Dict[str, Any]]:
    """Return MCP tool definitions"""
    return [
        {
            "name": "create_local_chat",
            "description": "Create a new local cursor-agent chat on this machine. Returns chat_id for sending tasks. Use this to create agents that work locally (not on remote devices).",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "name": {
                        "type": "string",
                        "description": "Optional chat name for organization"
                    }
                },
                "required": []
            }
        },
        {
            "name": "send_local_task",
            "description": "Delegate a task to a local cursor-agent. The agent runs on your local machine with access to the local filesystem. By default (wait=True), this blocks until the task completes. Set wait=False for fire-and-forget.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "chat_id": {
                        "type": "string",
                        "description": "Chat UUID (from create_local_chat)"
                    },
                    "prompt": {
                        "type": "string",
                        "description": "Task description or question for the local agent"
                    },
                    "model": {
                        "type": "string",
                        "description": "AI model to use (e.g., 'sonnet-4.5-thinking', 'gpt-5')"
                    },
                    "wait": {
                        "type": "boolean",
                        "description": "Wait for completion before returning (default: true)",
                        "default": True
                    },
                    "timeout": {
                        "type": "integer",
                        "description": "Maximum seconds to wait if wait=true (default: 300)",
                        "default": 300
                    }
                },
                "required": ["chat_id", "prompt"]
            }
        },
        {
            "name": "list_remote_devices",
            "description": "List all configured remote devices (SSH-accessible machines). Returns device ID, name, hostname, and connection status. Use this to find available devices before creating remote chats.",
            "inputSchema": {
                "type": "object",
                "properties": {},
                "required": []
            }
        },
        {
            "name": "add_remote_device",
            "description": "Register a new remote device for SSH-based cursor-agent execution. Requires SSH key authentication to be set up. After adding, use test_device_connection to verify connectivity.",
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
            "name": "test_device_connection",
            "description": "Test SSH connection to a remote device. Verifies that SSH authentication works and the device is reachable. Returns success status and error details if connection fails.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "device_id": {
                        "type": "string",
                        "description": "Device UUID (from list_remote_devices or add_remote_device)"
                    }
                },
                "required": ["device_id"]
            }
        },
        {
            "name": "create_remote_chat",
            "description": "Create a new chat conversation on a remote device. The chat will have access to the specified working directory. Returns chat_id for sending tasks.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "device_id": {
                        "type": "string",
                        "description": "Device UUID where chat should be created"
                    },
                    "working_directory": {
                        "type": "string",
                        "description": "Absolute path to working directory on remote device"
                    },
                    "name": {
                        "type": "string",
                        "description": "Optional chat name for organization"
                    }
                },
                "required": ["device_id", "working_directory"]
            }
        },
        {
            "name": "send_remote_task",
            "description": "Delegate a task to a remote cursor-agent. Each call to an existing chat has access to all previous messages - context is automatically maintained by cursor-agent. By default (wait=True), this blocks until the task completes and returns the result. Set wait=False for fire-and-forget. For better multi-turn UX, use get_chat_history first, then continue_conversation.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "chat_id": {
                        "type": "string",
                        "description": "Chat UUID (from create_remote_chat)"
                    },
                    "prompt": {
                        "type": "string",
                        "description": "Task description or question for the remote agent"
                    },
                    "model": {
                        "type": "string",
                        "description": "AI model to use (e.g., 'sonnet-4.5-thinking', 'gpt-5')"
                    },
                    "wait": {
                        "type": "boolean",
                        "description": "Wait for completion before returning (default: true)",
                        "default": True
                    },
                    "timeout": {
                        "type": "integer",
                        "description": "Maximum seconds to wait if wait=true (default: 300)",
                        "default": 300
                    }
                },
                "required": ["chat_id", "prompt"]
            }
        },
        {
            "name": "get_job_result",
            "description": "Check status and retrieve result of an async job. Use this after send_remote_task with wait=false.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "job_id": {
                        "type": "string",
                        "description": "Job UUID (from send_remote_task)"
                    }
                },
                "required": ["job_id"]
            }
        },
        {
            "name": "get_chat_history",
            "description": "Retrieve conversation history from a chat. Shows all messages exchanged with the remote agent. Use this to understand context before sending follow-up tasks. Works with both remote and local chats.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "chat_id": {
                        "type": "string",
                        "description": "Chat UUID (from create_remote_chat or existing chat)"
                    },
                    "limit": {
                        "type": "integer",
                        "description": "Maximum number of messages to retrieve (default: all messages)"
                    }
                },
                "required": ["chat_id"]
            }
        },
        {
            "name": "continue_conversation",
            "description": "Continue an existing conversation by sending a follow-up message. The remote agent has full access to all previous messages in the chat. Context is automatically maintained by cursor-agent. This is semantically clearer than send_remote_task for multi-turn conversations.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "chat_id": {
                        "type": "string",
                        "description": "Chat UUID (from create_remote_chat)"
                    },
                    "message": {
                        "type": "string",
                        "description": "Your follow-up message or question"
                    },
                    "model": {
                        "type": "string",
                        "description": "AI model to use (e.g., 'sonnet-4.5-thinking', 'gpt-5')"
                    },
                    "wait": {
                        "type": "boolean",
                        "description": "Wait for completion before returning (default: true)",
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
        {
            "name": "list_remote_chats",
            "description": "List all active remote chat sessions. Shows chat ID, device, working directory, message count, and last activity. Use this to find existing chats before creating new ones.",
            "inputSchema": {
                "type": "object",
                "properties": {},
                "required": []
            }
        }
    ]


async def handle_tool_call(client: BlinkApiClient, name: str, arguments: Dict[str, Any]) -> str:
    """Handle individual tool invocations"""
    
    if name == "create_local_chat":
        name_arg = arguments.get("name")
        result = await client.create_local_chat(name=name_arg)
        
        return (
            f"✅ **Local Chat Created**\n\n"
            f"Chat ID: {result.get('chat_id', '')}\n"
            f"Location: Local machine\n"
            f"Status: {result.get('status', 'unknown')}\n\n"
            f"💡 Use this chat_id with `send_local_task` to delegate work."
        )
    
    elif name == "send_local_task":
        chat_id = arguments.get("chat_id")
        if not chat_id:
            raise ValueError("Missing chat_id")
        
        wait = arguments.get("wait", True)
        
        prompt_data = {
            "prompt": arguments.get("prompt")
        }
        if arguments.get("model"):
            prompt_data["model"] = arguments.get("model")
        
        if not wait:
            # Use async endpoint (returns immediately with job_id, job executes in background)
            job_result = await client.send_prompt_async(chat_id, prompt_data)
            job_id = job_result.get("job_id")
            if not job_id:
                raise ValueError("Missing job_id in response")
            
            return (
                f"🚀 **Local Task Submitted**\n\n"
                f"Job ID: {job_id}\n\n"
                f"💡 Use `get_job_result` to check status."
            )
        else:
            # Use async endpoint but wait for completion
            job_result = await client.send_prompt_async(chat_id, prompt_data)
            job_id = job_result.get("job_id")
            if not job_id:
                raise ValueError("Missing job_id in response")
            
            timeout = arguments.get("timeout", 300)
            
            # Wait for completion
            job = await client.wait_for_job(job_id, timeout)
            result = job.get("result", {})
            
            if not result:
                return f"❌ **Task Failed**\n\nNo result returned from agent."
            
            output = f"✅ **Local Task Complete**\n\n"
            output += f"**Agent Response:**\n{result.get('response', 'No response')}\n\n"
            
            if result.get("error"):
                output += f"**Errors:** {result.get('error')}\n"
            
            return output
    
    elif name == "list_remote_devices":
        devices = await client.list_devices()
        if not devices:
            return "No remote devices configured. Use add_remote_device to register a new device."
        
        output = "📱 **Remote Devices:**\n\n"
        for device in devices:
            output += f"• **{device.get('name', 'Unknown')}** ({device.get('username', '')})\n"
            output += f"  - Hostname: {device.get('hostname', '')}\n"
            output += f"  - Status: {device.get('status', 'unknown')}\n"
            output += f"  - ID: {device.get('id', '')}\n\n"
        return output
    
    elif name == "add_remote_device":
        result = await client.add_device(arguments)
        device = result.get("device", {})
        return (
            f"✅ **Device Added Successfully**\n\n"
            f"Name: {device.get('name', 'Unknown')}\n"
            f"ID: {device.get('id', '')}\n"
            f"Hostname: {device.get('hostname', '')}\n\n"
            f"💡 Next step: Use `test_device_connection` to verify connectivity."
        )
    
    elif name == "test_device_connection":
        device_id = arguments.get("device_id")
        if not device_id:
            raise ValueError("Missing device_id")
        
        result = await client.test_device_connection(device_id)
        
        if result.get("success"):
            return (
                f"✅ **Connection Successful**\n\n"
                f"Device: {result.get('device_name', 'Unknown')}\n"
                f"Status: Online and reachable"
            )
        else:
            return (
                f"❌ **Connection Failed**\n\n"
                f"Device: {result.get('device_name', 'Unknown')}\n"
                f"Error: {result.get('stderr', 'Unknown error')}"
            )
    
    elif name == "create_remote_chat":
        device_id = arguments.get("device_id")
        if not device_id:
            raise ValueError("Missing device_id")
        
        result = await client.create_remote_chat(device_id, arguments)
        
        return (
            f"✅ **Remote Chat Created**\n\n"
            f"Chat ID: {result.get('chat_id', '')}\n"
            f"Device: {result.get('device_name', 'Unknown')}\n"
            f"Working Directory: {result.get('working_directory', '')}\n\n"
            f"💡 Use this chat_id with `send_remote_task` to delegate work."
        )
    
    elif name == "send_remote_task":
        chat_id = arguments.get("chat_id")
        if not chat_id:
            raise ValueError("Missing chat_id")
        
        wait = arguments.get("wait", True)
        
        prompt_data = {
            "prompt": arguments.get("prompt")
        }
        if arguments.get("model"):
            prompt_data["model"] = arguments.get("model")
        
        if not wait:
            # Use async endpoint (returns immediately with job_id, job executes in background)
            job_result = await client.send_prompt_async(chat_id, prompt_data)
            job_id = job_result.get("job_id")
            if not job_id:
                raise ValueError("Missing job_id in response")
            
            return (
                f"🚀 **Task Submitted**\n\n"
                f"Job ID: {job_id}\n\n"
                f"💡 Use `get_job_result` to check status."
            )
        else:
            # Use async endpoint but wait for completion
            job_result = await client.send_prompt_async(chat_id, prompt_data)
            job_id = job_result.get("job_id")
            if not job_id:
                raise ValueError("Missing job_id in response")
            
            timeout = arguments.get("timeout", 300)
            
            # Wait for completion
            job = await client.wait_for_job(job_id, timeout)
            result = job.get("result", {})
            
            # Parse the result JSON if it's a string
            if isinstance(result, str):
                import json
                try:
                    result = json.loads(result)
                except:
                    pass
            
            content = result.get("content", {}) if isinstance(result, dict) else {}
            assistant_response = content.get("assistant", "No response")
            
            return (
                f"✅ **Task Completed**\n\n"
                f"**Agent Response:**\n{assistant_response}\n\n"
                f"Job ID: {job_id}"
            )
    
    elif name == "get_job_result":
        job_id = arguments.get("job_id")
        if not job_id:
            raise ValueError("Missing job_id")
        
        job = await client.get_job_status(job_id)
        status = job.get("status", "unknown")
        
        if status == "completed":
            result = job.get("result")
            
            # Parse result if it's a JSON string
            if isinstance(result, str):
                import json
                try:
                    result = json.loads(result)
                except:
                    pass
            
            if isinstance(result, dict):
                content = result.get("content", {})
                assistant_response = content.get("assistant", "No response")
            else:
                assistant_response = str(result) if result else "No response"
            
            return (
                f"✅ **Job Completed**\n\n"
                f"**Agent Response:**\n{assistant_response}"
            )
        elif status == "failed":
            return (
                f"❌ **Job Failed**\n\n"
                f"Error: {job.get('error', 'Unknown error')}"
            )
        elif status in ["pending", "processing"]:
            return (
                f"⏳ **Job In Progress**\n\n"
                f"Status: {status}\n"
                f"Check again in a few moments."
            )
        else:
            return f"❓ Job status: {status}"
    
    elif name == "get_chat_history":
        chat_id = arguments.get("chat_id")
        if not chat_id:
            raise ValueError("Missing chat_id")
        
        limit = arguments.get("limit")
        
        chat_data = await client.get_chat_messages(chat_id, limit)
        metadata = chat_data.get("metadata", {})
        messages = chat_data.get("messages", [])
        
        if not messages:
            return (
                f"📜 **Chat History: {metadata.get('name', 'Untitled')}**\n\n"
                f"No messages yet in this chat.\n\n"
                f"💡 Use 'send_remote_task' or 'continue_conversation' to start the conversation."
            )
        
        output = (
            f"📜 **Chat History: {metadata.get('name', 'Untitled')}**\n"
            f"Device: {metadata.get('device_name', 'Unknown')} | "
            f"Messages: {chat_data.get('message_count', 0)} | "
            f"Format: {metadata.get('format', 'unknown')}\n\n"
            f"---\n"
        )
        
        for msg in messages:
            role = msg.get("type_label", "unknown")
            text = msg.get("text", "")
            created_at = msg.get("created_at", "")
            
            role_display = role.capitalize() if role else "Unknown"
            output += f"[{role_display}] {created_at}\n{text}\n\n"
        
        output += "---\n\n💡 Use 'continue_conversation' to add to this chat with full context."
        return output
    
    elif name == "continue_conversation":
        chat_id = arguments.get("chat_id")
        if not chat_id:
            raise ValueError("Missing chat_id")
        
        message = arguments.get("message")
        if not message:
            raise ValueError("Missing message")
        
        wait = arguments.get("wait", True)
        
        prompt_data = {
            "prompt": message
        }
        if arguments.get("model"):
            prompt_data["model"] = arguments.get("model")
        
        if not wait:
            # Use async endpoint (returns immediately with job_id, job executes in background)
            job_result = await client.send_prompt_async(chat_id, prompt_data)
            job_id = job_result.get("job_id")
            if not job_id:
                raise ValueError("Missing job_id in response")
            
            return (
                f"🚀 **Message Sent**\n\n"
                f"Job ID: {job_id}\n\n"
                f"💡 Use `get_job_result` to check status."
            )
        else:
            # Use async endpoint but wait for completion
            job_result = await client.send_prompt_async(chat_id, prompt_data)
            job_id = job_result.get("job_id")
            if not job_id:
                raise ValueError("Missing job_id in response")
            
            timeout = arguments.get("timeout", 300)
            
            # Wait for completion
            job = await client.wait_for_job(job_id, timeout)
            result = job.get("result", {})
            
            # Parse the result JSON if it's a string
            if isinstance(result, str):
                import json
                try:
                    result = json.loads(result)
                except:
                    pass
            
            content = result.get("content", {}) if isinstance(result, dict) else {}
            assistant_response = content.get("assistant", "No response")
            
            return (
                f"✅ **Response Received**\n\n"
                f"**Agent:**\n{assistant_response}\n\n"
                f"Job ID: {job_id}\n\n"
                f"💡 Use 'get_chat_history' to see full conversation."
            )
    
    elif name == "list_remote_chats":
        chats = await client.list_remote_chats()
        
        if not chats:
            return (
                "💬 **No Active Remote Chats**\n\n"
                "Use `create_remote_chat` to start a new conversation with a remote agent."
            )
        
        output = "💬 **Active Remote Chats:**\n\n"
        
        for idx, chat in enumerate(chats, 1):
            output += (
                f"{idx}. **{chat.get('name', 'Untitled')}**\n"
                f"   - ID: {chat.get('chat_id', '')}\n"
                f"   - Device: {chat.get('device_name', 'Unknown')}\n"
                f"   - Directory: {chat.get('working_directory', '')}\n"
                f"   - Messages: {chat.get('message_count', 0)}\n"
                f"   - Last Active: {chat.get('last_updated_at', 'Unknown')}\n\n"
            )
        
        output += "💡 Use 'get_chat_history' to see messages or 'continue_conversation' to add to a chat."
        return output
    
    else:
        raise ValueError(f"Unknown tool: {name}")


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
                    "version": "1.0.0"
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

