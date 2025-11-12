#!/usr/bin/env python3
"""
Cursor Chat REST API Server

Provides REST API access to Cursor chat database with direct SQLite queries.
No intermediate JSON/text file conversion - queries database in real-time.

Author: Generated for Cursor Chat Timeline Project
Version: 1.0
"""

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
import sqlite3
import json
from datetime import datetime
from typing import Optional, List, Dict, Any
from pydantic import BaseModel
import uvicorn
import os
import subprocess
import uuid as uuid_lib

# Database path - adjust if needed
DB_PATH = os.path.expanduser('~/Library/Application Support/Cursor/User/globalStorage/state.vscdb')

app = FastAPI(
    title="Cursor Chat API",
    version="1.0.0",
    description="REST API for Cursor chat database with direct SQLite queries"
)

# Enable CORS for web access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============================================================================
# Request/Response Models
# ============================================================================

class MessageCreate(BaseModel):
    text: str
    type: int = 1  # 1 = user, 2 = assistant
    
    class Config:
        json_schema_extra = {
            "example": {
                "text": "Hello, this is a test message",
                "type": 1
            }
        }

class ChatMetadata(BaseModel):
    chat_id: str
    name: Optional[str] = None
    created_at: Optional[int] = None
    created_at_iso: Optional[str] = None
    last_updated_at: Optional[int] = None
    last_updated_at_iso: Optional[str] = None
    is_archived: bool = False
    is_draft: bool = False
    total_lines_added: int = 0
    total_lines_removed: int = 0
    subtitle: Optional[str] = None
    message_count: int = 0

class Message(BaseModel):
    bubble_id: str
    type: int
    type_label: str
    text: str
    created_at: Optional[str] = None
    has_tool_call: bool = False
    has_thinking: bool = False
    has_code: bool = False
    has_todos: bool = False

class AgentPromptRequest(BaseModel):
    prompt: str
    include_history: bool = True
    max_history_messages: Optional[int] = 20
    model: Optional[str] = None
    output_format: str = "text"
    
    class Config:
        json_schema_extra = {
            "example": {
                "prompt": "Please help me understand this code",
                "include_history": True,
                "max_history_messages": 10,
                "model": "gpt-5",
                "output_format": "text"
            }
        }

# ============================================================================
# Helper Functions
# ============================================================================

def get_db_connection():
    """Get SQLite connection to Cursor database"""
    if not os.path.exists(DB_PATH):
        raise HTTPException(
            status_code=503,
            detail=f"Database not found at {DB_PATH}"
        )
    return sqlite3.connect(DB_PATH)

def parse_timestamp(ts_value) -> Optional[str]:
    """Parse timestamp to ISO format"""
    if not ts_value:
        return None
    try:
        if isinstance(ts_value, str):
            return ts_value
        if isinstance(ts_value, (int, float)):
            return datetime.fromtimestamp(ts_value / 1000.0).isoformat()
    except Exception as e:
        return None

def extract_message_content(bubble: Dict) -> str:
    """Extract all content from a bubble (text, tool calls, thinking, etc.)"""
    text_parts = []
    
    # Regular text
    if bubble.get('text'):
        text_parts.append(bubble['text'])
    
    # Tool calls
    if bubble.get('toolFormerData'):
        tool_data = bubble['toolFormerData']
        tool_name = tool_data.get('name', 'unknown')
        
        # Try to parse args for better display
        raw_args = tool_data.get('rawArgs', '')
        try:
            args = json.loads(raw_args) if raw_args else {}
            if 'explanation' in args:
                text_parts.append(f"[Tool Call: {tool_name}]\nPurpose: {args['explanation']}")
            elif 'command' in args:
                text_parts.append(f"[Tool Call: {tool_name}]\nCommand: {args['command']}")
            else:
                text_parts.append(f"[Tool Call: {tool_name}]")
        except:
            text_parts.append(f"[Tool Call: {tool_name}]")
    
    # Thinking/reasoning
    if bubble.get('thinking'):
        thinking = bubble['thinking']
        if isinstance(thinking, dict):
            thinking_text = thinking.get('text', str(thinking)[:200])
        else:
            thinking_text = str(thinking)[:200]
        text_parts.append(f"[Internal Reasoning]\n{thinking_text}")
    
    # Code blocks
    if bubble.get('codeBlocks'):
        code_blocks = bubble['codeBlocks']
        text_parts.append(f"[{len(code_blocks)} Code Block(s)]")
    
    # Todos
    if bubble.get('todos'):
        todos = bubble['todos']
        text_parts.append(f"[{len(todos)} Todo Item(s)]")
    
    return '\n\n'.join(text_parts) if text_parts else '[No content]'

# ============================================================================
# API Endpoints
# ============================================================================

@app.get("/")
def root():
    """API information and available endpoints"""
    return {
        "name": "Cursor Chat API",
        "version": "2.1.0",
        "description": "REST API for Cursor chat database with cursor-agent integration",
        "database": DB_PATH,
        "cursor_agent": {
            "installed": os.path.exists(CURSOR_AGENT_PATH),
            "path": CURSOR_AGENT_PATH
        },
        "endpoints": {
            "GET /": "API information",
            "GET /health": "Health check",
            "GET /chats": "List all chats with metadata",
            "GET /chats/{chat_id}": "Get all messages for a specific chat",
            "GET /chats/{chat_id}/metadata": "Get metadata for a specific chat",
            "GET /chats/{chat_id}/summary": "Get chat summary optimized for UI (NEW v2.1)",
            "POST /chats/{chat_id}/messages": "Send a message to a chat (DANGEROUS - disabled by default)",
            "POST /chats/{chat_id}/agent-prompt": "Send prompt to cursor-agent with chat history",
            "POST /chats/batch-info": "Get info for multiple chats at once (NEW v2.1)",
            "POST /agent/create-chat": "Create new cursor-agent chat",
            "GET /agent/models": "List available AI models"
        },
        "features": {
            "chat_continuation": "Continue existing Cursor conversations seamlessly",
            "context_preview": "Get recent messages before continuing",
            "batch_operations": "Fetch multiple chat summaries at once",
            "history_management": "Automatic history via cursor-agent --resume"
        },
        "documentation": "http://localhost:8000/docs"
    }

@app.get("/health")
def health_check():
    """Check if database is accessible and return basic stats"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Count chats
        cursor.execute("SELECT COUNT(*) FROM cursorDiskKV WHERE key LIKE 'composerData:%'")
        chat_count = cursor.fetchone()[0]
        
        # Count messages
        cursor.execute("SELECT COUNT(*) FROM cursorDiskKV WHERE key LIKE 'bubbleId:%'")
        message_count = cursor.fetchone()[0]
        
        conn.close()
        
        return {
            "status": "healthy",
            "database": "accessible",
            "database_path": DB_PATH,
            "total_chats": chat_count,
            "total_messages": message_count
        }
    except Exception as e:
        raise HTTPException(
            status_code=503,
            detail=f"Database unhealthy: {str(e)}"
        )

@app.get("/chats")
def list_chats(
    include_archived: bool = Query(False, description="Include archived chats"),
    sort_by: str = Query("last_updated", description="Sort by: last_updated, created, name"),
    limit: Optional[int] = Query(None, description="Maximum number of chats to return"),
    offset: int = Query(0, description="Number of chats to skip")
):
    """
    List all chats with metadata (direct SQLite query)

    Returns chat IDs, names, timestamps, status, and basic statistics.
    Does NOT return message content - use /chats/{chat_id} for that.
    """
    # Check if database exists - return empty list if not
    if not os.path.exists(DB_PATH):
        return {
            "total": 0,
            "returned": 0,
            "offset": offset,
            "chats": []
        }

    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        # Query all composer data
        cursor.execute("""
            SELECT key, value 
            FROM cursorDiskKV 
            WHERE key LIKE 'composerData:%'
        """)
        
        chats = []
        for key, value_blob in cursor.fetchall():
            try:
                # Parse JSON directly from SQLite
                data = json.loads(value_blob)
                
                # Skip archived if not requested
                if not include_archived and data.get('isArchived', False):
                    continue
                
                chat_id = data.get('composerId')
                
                chat_meta = {
                    "chat_id": chat_id,
                    "name": data.get('name', 'Untitled'),
                    "created_at": data.get('createdAt'),
                    "created_at_iso": parse_timestamp(data.get('createdAt')),
                    "last_updated_at": data.get('lastUpdatedAt'),
                    "last_updated_at_iso": parse_timestamp(data.get('lastUpdatedAt')),
                    "is_archived": data.get('isArchived', False),
                    "is_draft": data.get('isDraft', False),
                    "total_lines_added": data.get('totalLinesAdded', 0),
                    "total_lines_removed": data.get('totalLinesRemoved', 0),
                    "subtitle": data.get('subtitle'),
                    "unified_mode": data.get('unifiedMode'),
                    "message_count": len(data.get('fullConversationHeadersOnly', []))
                }
                
                chats.append(chat_meta)
            except json.JSONDecodeError:
                continue
        
        # Sort chats
        if sort_by == "last_updated":
            chats.sort(key=lambda x: x['last_updated_at'] or 0, reverse=True)
        elif sort_by == "created":
            chats.sort(key=lambda x: x['created_at'] or 0, reverse=True)
        elif sort_by == "name":
            chats.sort(key=lambda x: (x['name'] or 'Untitled').lower())
        
        # Apply pagination
        total_count = len(chats)
        if limit:
            chats = chats[offset:offset+limit]
        else:
            chats = chats[offset:]
        
        return {
            "total": total_count,
            "returned": len(chats),
            "offset": offset,
            "chats": chats
        }
        
    finally:
        conn.close()

@app.get("/chats/{chat_id}/metadata")
def get_chat_metadata(chat_id: str):
    """
    Get metadata for a specific chat (direct SQLite query)
    
    Returns chat information without message content.
    """
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute("""
            SELECT value 
            FROM cursorDiskKV 
            WHERE key = ?
        """, (f'composerData:{chat_id}',))
        
        row = cursor.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail=f"Chat {chat_id} not found")
        
        data = json.loads(row[0])
        
        return {
            "chat_id": data.get('composerId'),
            "name": data.get('name', 'Untitled'),
            "created_at": data.get('createdAt'),
            "created_at_iso": parse_timestamp(data.get('createdAt')),
            "last_updated_at": data.get('lastUpdatedAt'),
            "last_updated_at_iso": parse_timestamp(data.get('lastUpdatedAt')),
            "is_archived": data.get('isArchived', False),
            "is_draft": data.get('isDraft', False),
            "total_lines_added": data.get('totalLinesAdded', 0),
            "total_lines_removed": data.get('totalLinesRemoved', 0),
            "subtitle": data.get('subtitle'),
            "unified_mode": data.get('unifiedMode'),
            "context_usage_percent": data.get('contextUsagePercent'),
            "message_count": len(data.get('fullConversationHeadersOnly', []))
        }
        
    finally:
        conn.close()

@app.get("/chats/{chat_id}")
def get_chat_messages(
    chat_id: str,
    include_metadata: bool = Query(True, description="Include chat metadata in response"),
    limit: Optional[int] = Query(None, description="Maximum number of messages to return"),
    include_content: bool = Query(True, description="Extract full content (text, tools, reasoning)")
):
    """
    Get all messages for a specific chat (direct SQLite query)
    
    Returns all messages with full content including text, tool calls, 
    reasoning blocks, code blocks, and todos.
    """
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        # Get all bubbles for this chat
        cursor.execute("""
            SELECT key, value 
            FROM cursorDiskKV 
            WHERE key LIKE ?
            ORDER BY key
        """, (f'bubbleId:{chat_id}:%',))
        
        messages = []
        for key, value_blob in cursor.fetchall():
            try:
                bubble = json.loads(value_blob)
                
                # Extract bubble ID from key
                bubble_id = key.split(':')[-1]
                
                # Extract content
                if include_content:
                    text = extract_message_content(bubble)
                else:
                    text = bubble.get('text', '[Content not included]')
                
                message = {
                    "bubble_id": bubble_id,
                    "type": bubble.get('type'),  # 1=user, 2=assistant
                    "type_label": "user" if bubble.get('type') == 1 else "assistant",
                    "text": text,
                    "created_at": bubble.get('createdAt'),
                    "has_tool_call": bool(bubble.get('toolFormerData')),
                    "has_thinking": bool(bubble.get('thinking')),
                    "has_code": bool(bubble.get('codeBlocks')),
                    "has_todos": bool(bubble.get('todos')),
                }
                
                messages.append(message)
                
            except json.JSONDecodeError:
                continue
        
        # Sort by timestamp
        messages.sort(key=lambda x: x['created_at'] or '')
        
        # Apply limit if specified
        if limit:
            messages = messages[:limit]
        
        result = {
            "chat_id": chat_id,
            "message_count": len(messages),
            "messages": messages
        }
        
        # Include metadata if requested
        if include_metadata:
            cursor.execute("""
                SELECT value 
                FROM cursorDiskKV 
                WHERE key = ?
            """, (f'composerData:{chat_id}',))
            
            row = cursor.fetchone()
            if row:
                metadata = json.loads(row[0])
                result["metadata"] = {
                    "name": metadata.get('name', 'Untitled'),
                    "created_at": metadata.get('createdAt'),
                    "created_at_iso": parse_timestamp(metadata.get('createdAt')),
                    "last_updated_at": metadata.get('lastUpdatedAt'),
                    "last_updated_at_iso": parse_timestamp(metadata.get('lastUpdatedAt'))
                }
        
        return result
        
    finally:
        conn.close()

@app.post("/chats/{chat_id}/messages")
def send_message(
    chat_id: str, 
    message: MessageCreate,
    enable_write: bool = Query(False, description="Enable write operations (DANGEROUS)")
):
    """
    Send a message to a chat (direct SQLite write)
    
    ⚠️ WARNING: This writes directly to Cursor's database!
    - Only use when Cursor is CLOSED
    - Creates a new bubble in the database
    - May cause corruption if Cursor is running
    - Requires enable_write=true query parameter
    
    This endpoint is DISABLED by default for safety.
    """
    
    if not enable_write:
        raise HTTPException(
            status_code=403, 
            detail="Write operations disabled for safety. Add ?enable_write=true to enable. "
                   "WARNING: Only use when Cursor is closed!"
        )
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        # Verify chat exists
        cursor.execute("""
            SELECT value 
            FROM cursorDiskKV 
            WHERE key = ?
        """, (f'composerData:{chat_id}',))
        
        row = cursor.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail=f"Chat {chat_id} not found")
        
        # Generate new bubble ID
        import uuid
        bubble_id = str(uuid.uuid4())
        
        # Create minimal bubble data structure
        bubble_data = {
            "_v": 10,
            "type": message.type,
            "text": message.text,
            "bubbleId": bubble_id,
            "createdAt": datetime.now().isoformat() + 'Z',
            "approximateLintErrors": [],
            "lints": [],
            "codebaseContextChunks": [],
            "commits": [],
            "pullRequests": [],
            "attachedCodeChunks": [],
            "assistantSuggestedDiffs": [],
            "gitDiffs": [],
            "interpreterResults": [],
            "images": [],
            "attachedFolders": [],
            "attachedFoldersNew": [],
            "toolResults": [],
            "notepads": [],
            "capabilities": [],
            "capabilityStatuses": {},
        }
        
        # Insert bubble into database
        key = f'bubbleId:{chat_id}:{bubble_id}'
        value = json.dumps(bubble_data)
        
        cursor.execute("""
            INSERT INTO cursorDiskKV (key, value) 
            VALUES (?, ?)
        """, (key, value))
        
        # Update composer metadata to include this bubble
        composer_data = json.loads(row[0])
        headers = composer_data.get('fullConversationHeadersOnly', [])
        headers.append({
            "bubbleId": bubble_id,
            "type": message.type
        })
        composer_data['fullConversationHeadersOnly'] = headers
        composer_data['lastUpdatedAt'] = int(datetime.now().timestamp() * 1000)
        
        cursor.execute("""
            UPDATE cursorDiskKV 
            SET value = ? 
            WHERE key = ?
        """, (json.dumps(composer_data), f'composerData:{chat_id}'))
        
        conn.commit()
        
        return {
            "status": "success",
            "chat_id": chat_id,
            "bubble_id": bubble_id,
            "message": "Message sent (database updated)",
            "warning": "Make sure Cursor is closed to avoid database corruption"
        }
        
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=f"Error writing to database: {str(e)}")
    finally:
        conn.close()

# ============================================================================
# Cursor-Agent Integration
# ============================================================================

CURSOR_AGENT_PATH = os.path.expanduser("~/.local/bin/cursor-agent")
AVAILABLE_MODELS = [
    "composer-1", "auto", "sonnet-4.5", "sonnet-4.5-thinking",
    "gpt-5", "gpt-5-codex", "gpt-5-codex-high", "opus-4.1", "grok"
]

def run_cursor_agent(
    chat_id: str,
    prompt: str,
    model: Optional[str] = None,
    output_format: str = "text",
    timeout: int = 60
) -> Dict[str, Any]:
    """
    Execute cursor-agent CLI with chat history support
    
    Args:
        chat_id: Cursor chat ID to resume (provides history context)
        prompt: User prompt/question
        model: AI model to use (optional)
        output_format: Output format (text, json, stream-json)
        timeout: Command timeout in seconds
        
    Returns:
        Dict with stdout, stderr, returncode, success
    """
    try:
        # Build command
        cmd = [CURSOR_AGENT_PATH, "--print", "--force"]
        
        # Add model if specified
        if model:
            if model not in AVAILABLE_MODELS:
                raise ValueError(f"Invalid model '{model}'. Available: {', '.join(AVAILABLE_MODELS)}")
            cmd.extend(["--model", model])
        
        # Add output format
        cmd.extend(["--output-format", output_format])
        
        # Add resume with chat ID (this provides history)
        cmd.extend(["--resume", chat_id])
        
        # Add prompt
        cmd.append(prompt)
        
        # Execute command
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout
        )
        
        return {
            "stdout": result.stdout,
            "stderr": result.stderr,
            "returncode": result.returncode,
            "success": result.returncode == 0,
            "command": ' '.join(cmd)
        }
        
    except subprocess.TimeoutExpired:
        return {
            "stdout": "",
            "stderr": f"Command timed out after {timeout} seconds",
            "returncode": -1,
            "success": False,
            "command": ' '.join(cmd) if 'cmd' in locals() else "unknown"
        }
    except Exception as e:
        return {
            "stdout": "",
            "stderr": str(e),
            "returncode": -1,
            "success": False,
            "command": ' '.join(cmd) if 'cmd' in locals() else "unknown"
        }

@app.post("/chats/{chat_id}/agent-prompt")
def send_agent_prompt(
    chat_id: str,
    request: AgentPromptRequest,
    show_context: bool = Query(False, description="Include recent messages in response for context preview")
):
    """
    Send a prompt to cursor-agent with existing chat history
    
    This endpoint uses cursor-agent CLI with the --resume flag to automatically
    include all previous messages from the chat as context. The AI response is
    generated using the full conversation history.
    
    **Key Features:**
    - Maintains full conversation context via --resume
    - Supports multiple AI models (gpt-5, sonnet-4.5, opus-4.1, etc.)
    - Multiple output formats (text, json, stream-json)
    - Automatic history management
    - Optional context preview (show_context=true)
    
    **Usage:**
    ```
    POST /chats/{chat_id}/agent-prompt?show_context=true
    {
        "prompt": "What did we discuss about authentication?",
        "include_history": true,
        "max_history_messages": 20,
        "model": "gpt-5",
        "output_format": "text"
    }
    ```
    
    **Note:** The chat_id must be a valid Cursor chat ID (can be obtained from
    GET /chats or can be a newly created chat from cursor-agent create-chat).
    """
    # Verify cursor-agent is installed
    if not os.path.exists(CURSOR_AGENT_PATH):
        raise HTTPException(
            status_code=503,
            detail=f"cursor-agent not found at {CURSOR_AGENT_PATH}. Please install cursor-agent CLI."
        )
    
    # Verify chat exists and optionally get context
    chat_metadata = None
    context = None
    
    if request.include_history or show_context:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        try:
            # Check if chat exists in database
            cursor.execute("""
                SELECT value 
                FROM cursorDiskKV 
                WHERE key = ?
            """, (f'composerData:{chat_id}',))
            
            row = cursor.fetchone()
            if not row:
                # Chat doesn't exist in database - might be a new cursor-agent chat
                # Continue anyway, cursor-agent will handle it
                pass
            else:
                chat_metadata = json.loads(row[0])
                
                # If show_context requested, fetch recent messages
                if show_context:
                    cursor.execute("""
                        SELECT key, value FROM cursorDiskKV 
                        WHERE key LIKE ? 
                        ORDER BY key DESC LIMIT ?
                    """, (f'bubbleId:{chat_id}:%', request.max_history_messages or 5))
                    
                    messages = []
                    for key, value in cursor.fetchall():
                        try:
                            bubble = json.loads(value)
                            messages.append({
                                "role": "user" if bubble.get('type') == 1 else "assistant",
                                "text": extract_message_content(bubble),
                                "created_at": bubble.get('createdAt'),
                                "has_code": bool(bubble.get('codeBlocks')),
                                "has_thinking": bool(bubble.get('thinking')),
                                "has_tool_call": bool(bubble.get('toolFormerData'))
                            })
                        except (json.JSONDecodeError, KeyError):
                            continue
                    
                    # Reverse to chronological order
                    messages.reverse()
                    
                    context = {
                        "message_count": len(chat_metadata.get('fullConversationHeadersOnly', [])),
                        "recent_messages": messages,
                        "chat_name": chat_metadata.get('name', 'Untitled'),
                        "last_updated": parse_timestamp(chat_metadata.get('lastUpdatedAt'))
                    }
        finally:
            conn.close()
    
    # Execute cursor-agent with resume (provides history automatically)
    result = run_cursor_agent(
        chat_id=chat_id,
        prompt=request.prompt,
        model=request.model,
        output_format=request.output_format,
        timeout=90  # Longer timeout for agent operations
    )
    
    if not result["success"]:
        raise HTTPException(
            status_code=500,
            detail=f"cursor-agent execution failed: {result['stderr']}"
        )
    
    # Parse response based on format
    response_data = result["stdout"]
    
    if request.output_format == "json":
        try:
            response_data = json.loads(result["stdout"])
        except json.JSONDecodeError:
            # Return as text if JSON parsing fails
            pass
    elif request.output_format == "stream-json":
        # Parse each line as JSON
        lines = []
        for line in result["stdout"].strip().split('\n'):
            if line.strip():
                try:
                    lines.append(json.loads(line))
                except json.JSONDecodeError:
                    lines.append({"error": "Invalid JSON", "raw": line})
        response_data = lines
    
    # Build response with optional context
    response_obj = {
        "status": "success",
        "chat_id": chat_id,
        "prompt": request.prompt,
        "model": request.model or "default",
        "output_format": request.output_format,
        "response": response_data,
        "metadata": {
            "command": result["command"],
            "returncode": result["returncode"],
            "stderr": result["stderr"] if result["stderr"] else None
        }
    }
    
    # Add context if requested
    if context:
        response_obj["context"] = context
    
    return response_obj

@app.post("/agent/create-chat")
def create_agent_chat():
    """
    Create a new cursor-agent chat
    
    Returns a new chat ID that can be used with /chats/{chat_id}/agent-prompt
    to build a conversation with full history tracking.
    
    **Example:**
    ```
    POST /agent/create-chat
    
    Response:
    {
        "status": "success",
        "chat_id": "7c1283c9-bc7d-480a-8dc9-1ed382251471"
    }
    ```
    """
    if not os.path.exists(CURSOR_AGENT_PATH):
        raise HTTPException(
            status_code=503,
            detail=f"cursor-agent not found at {CURSOR_AGENT_PATH}"
        )
    
    try:
        result = subprocess.run(
            [CURSOR_AGENT_PATH, "create-chat"],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode != 0:
            raise HTTPException(
                status_code=500,
                detail=f"Failed to create chat: {result.stderr}"
            )
        
        chat_id = result.stdout.strip()
        
        return {
            "status": "success",
            "chat_id": chat_id,
            "message": "Chat created successfully"
        }
        
    except subprocess.TimeoutExpired:
        raise HTTPException(
            status_code=500,
            detail="create-chat command timed out"
        )
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error creating chat: {str(e)}"
        )

@app.get("/agent/models")
def list_available_models():
    """
    List all available AI models for cursor-agent
    
    Returns the list of models that can be used with the --model parameter.
    """
    return {
        "models": AVAILABLE_MODELS,
        "default": "auto",
        "recommended": ["gpt-5", "sonnet-4.5", "opus-4.1"]
    }

@app.get("/chats/{chat_id}/summary")
def get_chat_summary(
    chat_id: str,
    recent_count: int = Query(5, description="Number of recent messages to include")
):
    """
    Get chat summary optimized for continuation UI
    
    Returns chat metadata and recent messages in a format optimized for
    displaying in iOS/Flutter apps before continuing a conversation.
    
    **Usage:**
    ```
    GET /chats/{chat_id}/summary?recent_count=5
    ```
    
    **Response:**
    ```json
    {
      "chat_id": "...",
      "name": "Authentication Implementation",
      "created_at": "...",
      "message_count": 23,
      "last_updated": "...",
      "recent_messages": [...],
      "can_continue": true
    }
    ```
    """
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        # Get chat metadata
        cursor.execute("""
            SELECT value 
            FROM cursorDiskKV 
            WHERE key = ?
        """, (f'composerData:{chat_id}',))
        
        row = cursor.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail=f"Chat {chat_id} not found")
        
        metadata = json.loads(row[0])
        
        # Get recent messages
        cursor.execute("""
            SELECT key, value FROM cursorDiskKV 
            WHERE key LIKE ? 
            ORDER BY key DESC LIMIT ?
        """, (f'bubbleId:{chat_id}:%', recent_count))
        
        messages = []
        for key, value in cursor.fetchall():
            try:
                bubble = json.loads(value)
                messages.append({
                    "role": "user" if bubble.get('type') == 1 else "assistant",
                    "text": extract_message_content(bubble)[:200] + "..." if len(extract_message_content(bubble)) > 200 else extract_message_content(bubble),
                    "created_at": bubble.get('createdAt'),
                    "has_code": bool(bubble.get('codeBlocks')),
                    "has_thinking": bool(bubble.get('thinking')),
                    "has_tool_call": bool(bubble.get('toolFormerData')),
                    "has_todos": bool(bubble.get('todos'))
                })
            except (json.JSONDecodeError, KeyError):
                continue
        
        # Reverse to chronological order
        messages.reverse()
        
        # Determine if chat can be continued
        can_continue = True  # All cursor chats can be continued with --resume
        
        return {
            "chat_id": chat_id,
            "name": metadata.get('name', 'Untitled'),
            "created_at": parse_timestamp(metadata.get('createdAt')),
            "last_updated": parse_timestamp(metadata.get('lastUpdatedAt')),
            "message_count": len(metadata.get('fullConversationHeadersOnly', [])),
            "recent_messages": messages,
            "can_continue": can_continue,
            "has_code": any(m.get('has_code') for m in messages),
            "has_todos": any(m.get('has_todos') for m in messages),
            "participants": ["user", "assistant"]
        }
        
    finally:
        conn.close()

@app.post("/chats/batch-info")
def get_batch_chat_info(chat_ids: List[str]):
    """
    Get information for multiple chats at once
    
    Optimized for iOS list views where you need summary info for multiple chats.
    
    **Request:**
    ```json
    ["chat_id_1", "chat_id_2", "chat_id_3"]
    ```
    
    **Response:**
    ```json
    {
      "chats": [
        {"chat_id": "...", "name": "...", "message_count": 10},
        {"chat_id": "...", "name": "...", "message_count": 5}
      ],
      "not_found": ["chat_id_that_doesnt_exist"]
    }
    ```
    """
    conn = get_db_connection()
    cursor = conn.cursor()
    
    chats = []
    not_found = []
    
    try:
        for chat_id in chat_ids:
            cursor.execute("""
                SELECT value 
                FROM cursorDiskKV 
                WHERE key = ?
            """, (f'composerData:{chat_id}',))
            
            row = cursor.fetchone()
            if not row:
                not_found.append(chat_id)
                continue
            
            try:
                metadata = json.loads(row[0])
                chats.append({
                    "chat_id": chat_id,
                    "name": metadata.get('name', 'Untitled'),
                    "created_at": parse_timestamp(metadata.get('createdAt')),
                    "last_updated": parse_timestamp(metadata.get('lastUpdatedAt')),
                    "message_count": len(metadata.get('fullConversationHeadersOnly', [])),
                    "is_archived": metadata.get('isArchived', False),
                    "is_draft": metadata.get('isDraft', False)
                })
            except (json.JSONDecodeError, KeyError):
                not_found.append(chat_id)
        
        return {
            "chats": chats,
            "not_found": not_found,
            "total_requested": len(chat_ids),
            "total_found": len(chats)
        }
        
    finally:
        conn.close()

# ============================================================================
# Server Configuration
# ============================================================================

if __name__ == "__main__":
    print("=" * 80)
    print("Cursor Chat REST API Server")
    print("=" * 80)
    print(f"Database: {DB_PATH}")
    print("Starting server on http://localhost:8000")
    print("Documentation: http://localhost:8000/docs")
    print("=" * 80)
    print()
    
    uvicorn.run(
        app, 
        host="0.0.0.0", 
        port=8000,
        log_level="info"
    )

