"""Chat list and metadata endpoints"""

import json
import os
from typing import Optional
from fastapi import APIRouter, HTTPException, Query

from ..config import settings
from ..database import get_db_connection
from ..utils import parse_timestamp, extract_separated_content

router = APIRouter(prefix="/chats", tags=["chats"])


@router.get("")
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
    if not os.path.exists(settings.db_path):
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
        
        # Sort chats (handle None values safely)
        if sort_by == "last_updated":
            chats.sort(key=lambda x: x['last_updated_at'] if x['last_updated_at'] is not None else 0, reverse=True)
        elif sort_by == "created":
            chats.sort(key=lambda x: x['created_at'] if x['created_at'] is not None else 0, reverse=True)
        elif sort_by == "name":
            chats.sort(key=lambda x: (x['name'] or 'Untitled').lower())
        
        # Apply pagination
        total_count = len(chats)
        if limit is not None and limit == 0:
            chats = []
        elif limit:
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


@router.get("/{chat_id}/metadata")
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


@router.get("/{chat_id}")
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
                    "last_updated_at_iso": parse_timestamp(metadata.get('lastUpdatedAt')),
                    "is_archived": metadata.get('isArchived', False),
                    "is_draft": metadata.get('isDraft', False),
                    "total_lines_added": metadata.get('totalLinesAdded', 0),
                    "total_lines_removed": metadata.get('totalLinesRemoved', 0),
                    "subtitle": metadata.get('subtitle'),
                    "unified_mode": metadata.get('unifiedMode'),
                    "context_usage_percent": metadata.get('contextUsagePercent')
                }
        
        return result
        
    finally:
        conn.close()

