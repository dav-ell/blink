#!/usr/bin/env python3
"""
Cursor Chat REST API Server

Provides REST API access to Cursor chat database with direct SQLite queries.
No intermediate JSON/text file conversion - queries database in real-time.

Author: Generated for Cursor Chat Timeline Project
Version: 1.0
"""

from fastapi import FastAPI, HTTPException, Query, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
import sqlite3
import json
from datetime import datetime, timezone, timedelta
from typing import Optional, List, Dict, Any
from pydantic import BaseModel
import uvicorn
import os
import subprocess
import uuid as uuid_lib
from enum import Enum
import asyncio
import threading
from dataclasses import dataclass, field, asdict

# Database path - adjust if needed
DB_PATH = os.path.expanduser('~/Library/Application Support/Cursor/User/globalStorage/state.vscdb')

# ============================================================================
# Job Tracking System
# ============================================================================

class JobStatus(str, Enum):
    """Status of an async job"""
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"

@dataclass
class Job:
    """Represents an async cursor-agent job"""
    job_id: str
    chat_id: str
    prompt: str
    status: JobStatus
    created_at: datetime
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    result: Optional[str] = None
    error: Optional[str] = None
    user_bubble_id: Optional[str] = None
    assistant_bubble_id: Optional[str] = None
    model: Optional[str] = None
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization"""
        data = asdict(self)
        # Convert datetime objects to ISO strings
        for key in ['created_at', 'started_at', 'completed_at']:
            if data[key]:
                data[key] = data[key].isoformat()
        data['status'] = self.status.value
        return data
    
    def elapsed_seconds(self) -> Optional[float]:
        """Get elapsed time in seconds"""
        if self.started_at:
            end_time = self.completed_at or datetime.now(timezone.utc)
            return (end_time - self.started_at).total_seconds()
        return None

# In-memory job storage
jobs_storage: Dict[str, Job] = {}
jobs_lock = threading.Lock()

def create_job(chat_id: str, prompt: str, model: Optional[str] = None) -> Job:
    """Create a new job and store it"""
    job_id = str(uuid_lib.uuid4())
    job = Job(
        job_id=job_id,
        chat_id=chat_id,
        prompt=prompt,
        status=JobStatus.PENDING,
        created_at=datetime.now(timezone.utc),
        model=model
    )
    
    with jobs_lock:
        jobs_storage[job_id] = job
    
    return job

def get_job(job_id: str) -> Optional[Job]:
    """Get a job by ID"""
    with jobs_lock:
        return jobs_storage.get(job_id)

def update_job(job_id: str, **updates) -> Optional[Job]:
    """Update job fields"""
    with jobs_lock:
        job = jobs_storage.get(job_id)
        if job:
            for key, value in updates.items():
                if hasattr(job, key):
                    setattr(job, key, value)
        return job

def get_chat_jobs(chat_id: str, limit: int = 20) -> List[Job]:
    """Get all jobs for a chat, newest first"""
    with jobs_lock:
        chat_jobs = [job for job in jobs_storage.values() if job.chat_id == chat_id]
    
    # Sort by created_at descending
    chat_jobs.sort(key=lambda j: j.created_at, reverse=True)
    return chat_jobs[:limit]

def cleanup_old_jobs(max_age_hours: int = 1):
    """Remove completed/failed jobs older than max_age_hours"""
    cutoff = datetime.now(timezone.utc) - timedelta(hours=max_age_hours)
    
    with jobs_lock:
        to_remove = []
        for job_id, job in jobs_storage.items():
            if job.status in [JobStatus.COMPLETED, JobStatus.FAILED, JobStatus.CANCELLED]:
                if job.completed_at and job.completed_at < cutoff:
                    to_remove.append(job_id)
        
        for job_id in to_remove:
            del jobs_storage[job_id]
    
    return len(to_remove)

app = FastAPI(
    title="Cursor Chat API",
    version="2.0.0",
    description="REST API for Cursor chat database with async job support"
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
    # Separated content fields
    tool_calls: Optional[List[Dict[str, Any]]] = None
    thinking_content: Optional[str] = None
    code_blocks: Optional[List[Dict[str, Any]]] = None
    todos: Optional[List[Dict[str, Any]]] = None

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
        
        # Skip error tool calls that don't have a name
        # These are incomplete/failed tool calls with only {"additionalData": {"status": "error"}}
        if 'name' not in tool_data:
            # Check if this is just an error case
            if tool_data.get('additionalData', {}).get('status') == 'error':
                # Skip showing these error tool calls entirely
                pass
            else:
                # Unknown tool call structure - show minimal info
                text_parts.append(f"[Tool Call: incomplete data]")
        else:
            # Valid tool call with name
            tool_name = tool_data['name']
            
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

def extract_tool_calls(bubble: Dict) -> Optional[List[Dict[str, Any]]]:
    """Extract tool calls from a bubble as structured data"""
    if not bubble.get('toolFormerData'):
        return None
    
    tool_data = bubble['toolFormerData']
    
    # Skip error tool calls that don't have a name
    if 'name' not in tool_data:
        if tool_data.get('additionalData', {}).get('status') == 'error':
            return None
        return [{"name": "unknown", "description": "incomplete data"}]
    
    tool_name = tool_data['name']
    raw_args = tool_data.get('rawArgs', '')
    
    try:
        args = json.loads(raw_args) if raw_args else {}
        tool_call = {
            "name": tool_name,
            "explanation": args.get('explanation', ''),
            "command": args.get('command', ''),
            "arguments": args
        }
        return [tool_call]
    except:
        return [{"name": tool_name, "explanation": "", "arguments": {}}]

def extract_thinking(bubble: Dict) -> Optional[str]:
    """Extract thinking/reasoning content from a bubble"""
    if not bubble.get('thinking'):
        return None
    
    thinking = bubble['thinking']
    if isinstance(thinking, dict):
        return thinking.get('text', str(thinking))
    return str(thinking)

def extract_separated_content(bubble: Dict) -> Dict[str, Any]:
    """Extract content separated by type"""
    # Handle todos - may be strings or objects in database
    todos = bubble.get('todos')
    if todos and isinstance(todos, list):
        # Filter out non-dict items (strings from Cursor IDE)
        todos = [t for t in todos if isinstance(t, dict)]
        if not todos:
            todos = None
    
    # Handle code blocks - may be strings or objects
    code_blocks = bubble.get('codeBlocks')
    if code_blocks and isinstance(code_blocks, list):
        # Filter out non-dict items
        code_blocks = [cb for cb in code_blocks if isinstance(cb, dict)]
        if not code_blocks:
            code_blocks = None
    
    return {
        "text": bubble.get('text', ''),
        "tool_calls": extract_tool_calls(bubble),
        "thinking": extract_thinking(bubble),
        "code_blocks": code_blocks,
        "todos": todos
    }

def create_bubble_data(bubble_id: str, message_type: int, text: str) -> Dict[str, Any]:
    """Create a complete bubble data structure matching Cursor's format
    
    This includes all fields that Cursor expects to properly load and display chats.
    Missing fields can cause the Cursor IDE to fail when loading the chat.
    """
    
    # Generate a unique request ID for this bubble
    request_id = str(uuid_lib.uuid4())
    checkpoint_id = str(uuid_lib.uuid4())
    
    # Create Lexical editor richText structure
    rich_text = {
        "root": {
            "children": [{
                "children": [{
                    "detail": 0,
                    "format": 0,
                    "mode": "normal",
                    "style": "",
                    "text": text,
                    "type": "text",
                    "version": 1
                }],
                "direction": None,
                "format": "",
                "indent": 0,
                "type": "paragraph",
                "version": 1
            }],
            "direction": None,
            "format": "",
            "indent": 0,
            "type": "root",
            "version": 1
        }
    }
    
    bubble = {
        "_v": 3,
        "type": message_type,  # 1=user, 2=assistant
        "text": text,
        "bubbleId": bubble_id,
        "createdAt": datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
        
        # Core arrays (usually empty for basic messages)
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
        "multiFileLinterErrors": [],
        "diffHistories": [],
        "recentLocationsHistory": [],
        "recentlyViewedFiles": [],
        "fileDiffTrajectories": [],
        "docsReferences": [],
        "webReferences": [],
        "aiWebSearchResults": [],
        "attachedFoldersListDirResults": [],
        "humanChanges": [],
        
        # Additional arrays required by Cursor
        "allThinkingBlocks": [],
        "attachedFileCodeChunksMetadataOnly": [],
        "capabilityContexts": [],
        "consoleLogs": [],
        "contextPieces": [],
        "cursorRules": [],
        "deletedFiles": [],
        "diffsForCompressingFiles": [],
        "diffsSinceLastApply": [],
        "documentationSelections": [],
        "editTrailContexts": [],
        "externalLinks": [],
        "knowledgeItems": [],
        "projectLayouts": [],
        "relevantFiles": [],
        "suggestedCodeBlocks": [],
        "summarizedComposers": [],
        "todos": [],
        "uiElementPicked": [],
        "userResponsesToSuggestedCodeBlocks": [],
        
        # Capability statuses (required structure)
        "capabilityStatuses": {
            "mutate-request": [],
            "start-submit-chat": [],
            "before-submit-chat": [],
            "chat-stream-finished": [],
            "before-apply": [],
            "after-apply": [],
            "accept-all-edits": [],
            "composer-done": [],
            "process-stream": [],
            "add-pending-action": []
        },
        
        # Boolean flags
        "isAgentic": message_type == 1,  # True for user messages
        "existedSubsequentTerminalCommand": False,
        "existedPreviousTerminalCommand": False,
        "editToolSupportsSearchAndReplace": True,
        "isNudge": False,
        "isPlanExecution": False,
        "isQuickSearchQuery": False,
        "isRefunded": False,
        "skipRendering": False,
        "useWeb": False,
        
        # Critical fields for Cursor IDE
        "supportedTools": [1, 41, 7, 38, 8, 9, 11, 12, 15, 18, 19, 25, 27, 43, 46, 47, 29, 30, 32, 34, 35, 39, 40, 42, 44, 45],
        "tokenCount": {
            "inputTokens": 0,
            "outputTokens": 0
        },
        "context": {
            "composers": [],
            "quotes": [],
            "selectedCommits": [],
            "selectedPullRequests": [],
            "selectedImages": [],
            "folderSelections": [],
            "fileSelections": [],
            "terminalFiles": [],
            "selections": [],
            "terminalSelections": [],
            "selectedDocs": [],
            "externalLinks": [],
            "cursorRules": [],
            "cursorCommands": [],
            "uiElementSelections": [],
            "consoleLogs": [],
            "mentions": []
        },
        
        # Identifiers
        "requestId": request_id,
        "checkpointId": checkpoint_id,
        
        # Rich text representation (Lexical editor format)
        "richText": json.dumps(rich_text),
        
        # Unified mode (standard value)
        "unifiedMode": 5,
    }
    
    # Add model info for assistant messages
    if message_type == 2:
        bubble["modelInfo"] = {
            "modelName": "claude-4.5-sonnet"
        }
    
    return bubble

def save_message_to_db(
    conn: sqlite3.Connection,
    chat_id: str,
    bubble_id: str,
    bubble_data: Dict[str, Any]
) -> None:
    """Save a message bubble to the database"""
    cursor = conn.cursor()
    key = f'bubbleId:{chat_id}:{bubble_id}'
    value = json.dumps(bubble_data)
    
    cursor.execute(
        "INSERT INTO cursorDiskKV (key, value) VALUES (?, ?)",
        (key, value)
    )

def update_chat_metadata(
    conn: sqlite3.Connection,
    chat_id: str,
    new_bubble_ids: List[tuple]  # [(bubble_id, type), ...]
) -> None:
    """Update chat metadata to include new messages
    
    Ensures all required fields are present for Cursor IDE compatibility.
    """
    cursor = conn.cursor()
    
    # Get existing metadata
    cursor.execute(
        "SELECT value FROM cursorDiskKV WHERE key = ?",
        (f'composerData:{chat_id}',)
    )
    row = cursor.fetchone()
    if not row:
        raise ValueError(f"Chat {chat_id} not found")
    
    metadata = json.loads(row[0])
    
    # Ensure critical fields exist
    if '_v' not in metadata:
        metadata['_v'] = 10
    
    if 'hasLoaded' not in metadata:
        metadata['hasLoaded'] = True
    
    if 'text' not in metadata:
        metadata['text'] = ""
    
    # Ensure richText exists (Lexical editor state)
    if 'richText' not in metadata:
        metadata['richText'] = json.dumps({
            "root": {
                "children": [{
                    "children": [],
                    "format": "",
                    "indent": 0,
                    "type": "paragraph",
                    "version": 1
                }],
                "format": "",
                "indent": 0,
                "type": "root",
                "version": 1
            }
        })
    
    # Add new messages to headers
    headers = metadata.get('fullConversationHeadersOnly', [])
    for bubble_id, msg_type in new_bubble_ids:
        headers.append({
            "bubbleId": bubble_id,
            "type": msg_type
        })
    metadata['fullConversationHeadersOnly'] = headers
    
    # Update timestamp
    metadata['lastUpdatedAt'] = int(datetime.now().timestamp() * 1000)
    
    # Save back
    cursor.execute(
        "UPDATE cursorDiskKV SET value = ? WHERE key = ?",
        (json.dumps(metadata), f'composerData:{chat_id}')
    )

def validate_bubble_structure(bubble_data: Dict[str, Any]) -> bool:
    """Validate that bubble has required fields matching Cursor's format"""
    required_fields = [
        "_v", "type", "text", "bubbleId", "createdAt",
        "approximateLintErrors", "lints", "capabilities", "capabilityStatuses"
    ]
    return all(field in bubble_data for field in required_fields)

# ============================================================================
# API Endpoints
# ============================================================================

@app.get("/")
def root():
    """API information and available endpoints"""
    return {
        "name": "Cursor Chat API",
        "version": "2.0.0",
        "description": "REST API for Cursor chat database with async job support",
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
            "GET /chats/{chat_id}/summary": "Get chat summary optimized for UI",
            "POST /chats/{chat_id}/messages": "Send a message to a chat (DANGEROUS - disabled by default)",
            "POST /chats/{chat_id}/agent-prompt": "Send prompt to cursor-agent (synchronous, blocks until complete)",
            "POST /chats/{chat_id}/agent-prompt-async": "Submit prompt asynchronously (NEW v2.0 - returns immediately)",
            "GET /jobs/{job_id}": "Get full job details including status and result (NEW v2.0)",
            "GET /jobs/{job_id}/status": "Quick status check for a job (NEW v2.0)",
            "GET /chats/{chat_id}/jobs": "List all jobs for a chat (NEW v2.0)",
            "DELETE /jobs/{job_id}": "Cancel a pending or processing job (NEW v2.0)",
            "POST /chats/batch-info": "Get info for multiple chats at once",
            "POST /agent/create-chat": "Create new cursor-agent chat",
            "GET /agent/models": "List available AI models"
        },
        "features": {
            "async_jobs": "Submit prompts asynchronously and poll for results (NEW v2.0)",
            "concurrent_processing": "Run multiple cursor-agent calls simultaneously (NEW v2.0)",
            "job_tracking": "Track job status with elapsed time and detailed results (NEW v2.0)",
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
                
                # Extract content - now separated by type
                if include_content:
                    separated = extract_separated_content(bubble)
                    text = separated['text']
                    tool_calls = separated['tool_calls']
                    thinking_content = separated['thinking']
                    code_blocks = separated['code_blocks']
                    todos = separated['todos']
                else:
                    text = bubble.get('text', '[Content not included]')
                    tool_calls = None
                    thinking_content = None
                    code_blocks = None
                    todos = None
                
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
                    "tool_calls": tool_calls,
                    "thinking_content": thinking_content,
                    "code_blocks": code_blocks,
                    "todos": todos,
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

def execute_job_in_background(job_id: str):
    """
    Execute a cursor-agent job in the background
    
    This function:
    1. Marks job as processing
    2. Writes user message to database
    3. Calls cursor-agent
    4. Writes AI response to database
    5. Updates job status (completed or failed)
    """
    job = get_job(job_id)
    if not job:
        return
    
    try:
        # Mark as processing
        update_job(
            job_id,
            status=JobStatus.PROCESSING,
            started_at=datetime.now(timezone.utc)
        )
        
        # Get database connection
        conn = get_db_connection()
        
        try:
            # Verify chat exists
            cursor = conn.cursor()
            cursor.execute(
                "SELECT value FROM cursorDiskKV WHERE key = ?",
                (f'composerData:{job.chat_id}',)
            )
            if not cursor.fetchone():
                raise ValueError(f"Chat {job.chat_id} not found")
            
            # Start transaction
            conn.execute("BEGIN TRANSACTION")
            
            # Generate bubble IDs
            user_bubble_id = str(uuid_lib.uuid4())
            assistant_bubble_id = str(uuid_lib.uuid4())
            
            # Create and save user message bubble
            user_bubble = create_bubble_data(user_bubble_id, 1, job.prompt)
            if not validate_bubble_structure(user_bubble):
                raise ValueError("Invalid user bubble structure")
            
            save_message_to_db(conn, job.chat_id, user_bubble_id, user_bubble)
            
            # Call cursor-agent for AI response
            result = run_cursor_agent(
                chat_id=job.chat_id,
                prompt=job.prompt,
                model=job.model,
                output_format="text",
                timeout=120  # 2 minutes for async jobs
            )
            
            if not result["success"]:
                # Rollback on cursor-agent failure
                conn.rollback()
                conn.close()
                
                update_job(
                    job_id,
                    status=JobStatus.FAILED,
                    completed_at=datetime.now(timezone.utc),
                    error=f"cursor-agent failed: {result['stderr']}"
                )
                return
            
            # Parse AI response
            ai_response_text = result["stdout"].strip()
            
            # Create and save AI response bubble
            assistant_bubble = create_bubble_data(assistant_bubble_id, 2, ai_response_text)
            if not validate_bubble_structure(assistant_bubble):
                conn.rollback()
                conn.close()
                
                update_job(
                    job_id,
                    status=JobStatus.FAILED,
                    completed_at=datetime.now(timezone.utc),
                    error="Invalid assistant bubble structure"
                )
                return
            
            save_message_to_db(conn, job.chat_id, assistant_bubble_id, assistant_bubble)
            
            # Update chat metadata with both messages
            update_chat_metadata(conn, job.chat_id, [
                (user_bubble_id, 1),
                (assistant_bubble_id, 2)
            ])
            
            # Commit transaction
            conn.commit()
            conn.close()
            
            # Mark job as completed
            update_job(
                job_id,
                status=JobStatus.COMPLETED,
                completed_at=datetime.now(timezone.utc),
                result=ai_response_text,
                user_bubble_id=user_bubble_id,
                assistant_bubble_id=assistant_bubble_id
            )
            
        except Exception as e:
            conn.rollback()
            conn.close()
            raise e
            
    except Exception as e:
        # Mark job as failed
        update_job(
            job_id,
            status=JobStatus.FAILED,
            completed_at=datetime.now(timezone.utc),
            error=str(e)
        )

@app.post("/chats/{chat_id}/agent-prompt")
def send_agent_prompt(
    chat_id: str,
    request: AgentPromptRequest,
    show_context: bool = Query(False, description="Include recent messages in response")
):
    """
    Send a prompt with manual database persistence.
    
    This endpoint:
    1. Writes user message to database
    2. Calls cursor-agent for AI response
    3. Writes AI response to database
    4. Rolls back if any step fails
    
    **Usage:**
    ```
    POST /chats/{chat_id}/agent-prompt
    {
        "prompt": "What did we discuss about authentication?",
        "include_history": true,
        "model": "gpt-5",
        "output_format": "text"
    }
    ```
    """
    if not os.path.exists(CURSOR_AGENT_PATH):
        raise HTTPException(
            status_code=503,
            detail=f"cursor-agent not found at {CURSOR_AGENT_PATH}"
        )
    
    conn = get_db_connection()
    
    try:
        # Check if chat exists, create if it doesn't
        cursor = conn.cursor()
        cursor.execute(
            "SELECT value FROM cursorDiskKV WHERE key = ?",
            (f'composerData:{chat_id}',)
        )
        existing_chat = cursor.fetchone()
        
        if not existing_chat:
            # Chat doesn't exist - create minimal metadata
            # This happens when using /agent/create-chat which only generates an ID
            now_ms = int(datetime.now().timestamp() * 1000)
            
            chat_metadata = {
                "_v": 10,
                "composerId": chat_id,
                "name": "Untitled",
                "richText": json.dumps({
                    "root": {
                        "children": [{
                            "children": [],
                            "format": "",
                            "indent": 0,
                            "type": "paragraph",
                            "version": 1
                        }],
                        "format": "",
                        "indent": 0,
                        "type": "root",
                        "version": 1
                    }
                }),
                "hasLoaded": True,
                "text": "",
                "fullConversationHeadersOnly": [],
                "createdAt": now_ms,
                "lastUpdatedAt": now_ms,
                "isArchived": False,
                "isDraft": False,
                "totalLinesAdded": 0,
                "totalLinesRemoved": 0,
            }
            
            cursor.execute(
                "INSERT INTO cursorDiskKV (key, value) VALUES (?, ?)",
                (f'composerData:{chat_id}', json.dumps(chat_metadata))
            )
            conn.commit()
        
        # Start transaction
        conn.execute("BEGIN TRANSACTION")
        
        # Generate bubble IDs
        user_bubble_id = str(uuid_lib.uuid4())
        assistant_bubble_id = str(uuid_lib.uuid4())
        
        # Create and validate user message bubble
        user_bubble = create_bubble_data(user_bubble_id, 1, request.prompt)
        if not validate_bubble_structure(user_bubble):
            raise ValueError("Invalid user bubble structure")
        
        # Save user message
        save_message_to_db(conn, chat_id, user_bubble_id, user_bubble)
        
        # Call cursor-agent for AI response
        result = run_cursor_agent(
            chat_id=chat_id,
            prompt=request.prompt,
            model=request.model,
            output_format=request.output_format,
            timeout=90
        )
        
        if not result["success"]:
            # Rollback on cursor-agent failure
            conn.rollback()
            conn.close()
            raise HTTPException(
                status_code=500,
                detail=f"cursor-agent failed: {result['stderr']}"
            )
        
        # Parse AI response
        ai_response_text = result["stdout"].strip()
        
        # Create and validate AI response bubble
        assistant_bubble = create_bubble_data(assistant_bubble_id, 2, ai_response_text)
        if not validate_bubble_structure(assistant_bubble):
            conn.rollback()
            conn.close()
            raise ValueError("Invalid assistant bubble structure")
        
        # Save AI response
        save_message_to_db(conn, chat_id, assistant_bubble_id, assistant_bubble)
        
        # Update chat metadata with both messages
        update_chat_metadata(conn, chat_id, [
            (user_bubble_id, 1),
            (assistant_bubble_id, 2)
        ])
        
        # Commit transaction
        conn.commit()
        
        # Build response
        response_obj = {
            "status": "success",
            "chat_id": chat_id,
            "prompt": request.prompt,
            "model": request.model or "default",
            "output_format": request.output_format,
            "response": ai_response_text,
            "user_bubble_id": user_bubble_id,
            "assistant_bubble_id": assistant_bubble_id,
            "metadata": {
                "command": result["command"],
                "returncode": result["returncode"],
                "stderr": result["stderr"] if result["stderr"] else None
            }
        }
        
        return response_obj
        
    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"Error sending message: {str(e)}"
        )
    finally:
        conn.close()

# ============================================================================
# Async Job Endpoints
# ============================================================================

@app.post("/chats/{chat_id}/agent-prompt-async")
def submit_prompt_async(
    chat_id: str,
    request: AgentPromptRequest,
    background_tasks: BackgroundTasks
):
    """
    Submit a prompt asynchronously and return immediately with job ID
    
    The job will be processed in the background. Use GET /jobs/{job_id}
    to check status and retrieve the result when complete.
    
    **Usage:**
    ```
    POST /chats/{chat_id}/agent-prompt-async
    {
        "prompt": "What did we discuss about authentication?",
        "model": "gpt-5"
    }
    
    Response:
    {
        "job_id": "abc-123-def",
        "status": "pending",
        "chat_id": "...",
        "message": "Job submitted successfully"
    }
    ```
    """
    if not os.path.exists(CURSOR_AGENT_PATH):
        raise HTTPException(
            status_code=503,
            detail=f"cursor-agent not found at {CURSOR_AGENT_PATH}"
        )
    
    # Verify chat exists
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "SELECT value FROM cursorDiskKV WHERE key = ?",
            (f'composerData:{chat_id}',)
        )
        if not cursor.fetchone():
            conn.close()
            raise HTTPException(status_code=404, detail=f"Chat {chat_id} not found")
        conn.close()
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error checking chat: {str(e)}")
    
    # Create job
    job = create_job(chat_id, request.prompt, request.model)
    
    # Schedule background execution
    background_tasks.add_task(execute_job_in_background, job.job_id)
    
    return {
        "job_id": job.job_id,
        "status": job.status.value,
        "chat_id": job.chat_id,
        "message": "Job submitted successfully",
        "created_at": job.created_at.isoformat()
    }

@app.get("/jobs/{job_id}")
def get_job_details(job_id: str):
    """
    Get full job details including status and result
    
    **Response for completed job:**
    ```json
    {
        "job_id": "...",
        "chat_id": "...",
        "status": "completed",
        "prompt": "...",
        "result": "AI response text...",
        "created_at": "2025-11-12T10:00:00Z",
        "started_at": "2025-11-12T10:00:01Z",
        "completed_at": "2025-11-12T10:00:15Z",
        "elapsed_seconds": 14.5,
        "user_bubble_id": "...",
        "assistant_bubble_id": "..."
    }
    ```
    
    **Response for failed job:**
    ```json
    {
        "job_id": "...",
        "status": "failed",
        "error": "cursor-agent failed: ...",
        ...
    }
    ```
    """
    job = get_job(job_id)
    if not job:
        raise HTTPException(status_code=404, detail=f"Job {job_id} not found")
    
    response = job.to_dict()
    response['elapsed_seconds'] = job.elapsed_seconds()
    
    return response

@app.get("/jobs/{job_id}/status")
def get_job_status_quick(job_id: str):
    """
    Quick status check (lighter response than full job details)
    
    **Response:**
    ```json
    {
        "job_id": "...",
        "status": "processing",
        "elapsed_seconds": 5.2
    }
    ```
    """
    job = get_job(job_id)
    if not job:
        raise HTTPException(status_code=404, detail=f"Job {job_id} not found")
    
    return {
        "job_id": job.job_id,
        "status": job.status.value,
        "elapsed_seconds": job.elapsed_seconds()
    }

@app.get("/chats/{chat_id}/jobs")
def list_chat_jobs(
    chat_id: str,
    limit: int = Query(20, description="Maximum number of jobs to return"),
    status_filter: Optional[str] = Query(None, description="Filter by status (pending, processing, completed, failed)")
):
    """
    List all jobs for a chat
    
    **Usage:**
    ```
    GET /chats/{chat_id}/jobs?limit=10&status_filter=processing
    ```
    
    **Response:**
    ```json
    {
        "chat_id": "...",
        "total": 15,
        "jobs": [
            {
                "job_id": "...",
                "status": "processing",
                "prompt": "...",
                "created_at": "...",
                "elapsed_seconds": 5.2
            },
            ...
        ]
    }
    ```
    """
    jobs = get_chat_jobs(chat_id, limit)
    
    # Filter by status if requested
    if status_filter:
        try:
            filter_status = JobStatus(status_filter)
            jobs = [j for j in jobs if j.status == filter_status]
        except ValueError:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid status filter. Valid values: {[s.value for s in JobStatus]}"
            )
    
    jobs_data = []
    for job in jobs:
        job_dict = job.to_dict()
        job_dict['elapsed_seconds'] = job.elapsed_seconds()
        jobs_data.append(job_dict)
    
    return {
        "chat_id": chat_id,
        "total": len(jobs_data),
        "jobs": jobs_data
    }

@app.delete("/jobs/{job_id}")
def cancel_job(job_id: str):
    """
    Cancel a pending or processing job
    
    Note: Jobs that are already being executed by cursor-agent cannot be
    interrupted, but will be marked as cancelled once they complete.
    
    **Response:**
    ```json
    {
        "job_id": "...",
        "status": "cancelled",
        "message": "Job cancelled successfully"
    }
    ```
    """
    job = get_job(job_id)
    if not job:
        raise HTTPException(status_code=404, detail=f"Job {job_id} not found")
    
    if job.status in [JobStatus.COMPLETED, JobStatus.FAILED]:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot cancel job with status: {job.status.value}"
        )
    
    update_job(
        job_id,
        status=JobStatus.CANCELLED,
        completed_at=datetime.now(timezone.utc),
        error="Cancelled by user"
    )
    
    return {
        "job_id": job_id,
        "status": "cancelled",
        "message": "Job cancelled successfully"
    }

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

