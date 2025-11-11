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
        "version": "1.0.0",
        "description": "REST API for Cursor chat database with direct SQLite queries",
        "database": DB_PATH,
        "endpoints": {
            "GET /": "API information",
            "GET /health": "Health check",
            "GET /chats": "List all chats with metadata",
            "GET /chats/{chat_id}": "Get all messages for a specific chat",
            "GET /chats/{chat_id}/metadata": "Get metadata for a specific chat",
            "POST /chats/{chat_id}/messages": "Send a message to a chat (DANGEROUS - disabled by default)"
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

