"""Message write endpoint (DANGEROUS - disabled by default)"""

import json
import uuid
from datetime import datetime
from fastapi import APIRouter, HTTPException, Query

from ..models.message import MessageCreate
from ..database import get_db_connection

router = APIRouter(prefix="/chats", tags=["messages"])


@router.post("/{chat_id}/messages")
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

