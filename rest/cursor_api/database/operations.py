"""Database write operations for chat and messages"""

import json
import sqlite3
from datetime import datetime
from typing import Dict, Any, List


def save_message_to_db(
    conn: sqlite3.Connection,
    chat_id: str,
    bubble_id: str,
    bubble_data: Dict[str, Any]
) -> None:
    """Save a message bubble to the database
    
    Args:
        conn: SQLite connection
        chat_id: Chat UUID
        bubble_id: Message bubble UUID
        bubble_data: Complete bubble data structure
    """
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
    
    Args:
        conn: SQLite connection
        chat_id: Chat UUID
        new_bubble_ids: List of tuples (bubble_id, message_type)
        
    Raises:
        ValueError: If chat not found
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

