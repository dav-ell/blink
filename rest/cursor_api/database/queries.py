"""Database query functions for reading chat data"""

import json
import sqlite3
from typing import List, Dict, Any, Optional, Tuple


def get_all_chat_ids(conn: sqlite3.Connection) -> List[str]:
    """Get all chat IDs from database
    
    Args:
        conn: SQLite connection
        
    Returns:
        List of chat IDs
    """
    cursor = conn.cursor()
    cursor.execute("""
        SELECT key FROM cursorDiskKV 
        WHERE key LIKE 'composerData:%'
    """)
    
    chat_ids = []
    for (key,) in cursor.fetchall():
        chat_id = key.replace('composerData:', '')
        chat_ids.append(chat_id)
    
    return chat_ids


def get_chat_metadata(conn: sqlite3.Connection, chat_id: str) -> Optional[Dict[str, Any]]:
    """Get metadata for a specific chat
    
    Args:
        conn: SQLite connection
        chat_id: Chat UUID
        
    Returns:
        Chat metadata dictionary or None if not found
    """
    cursor = conn.cursor()
    cursor.execute(
        "SELECT value FROM cursorDiskKV WHERE key = ?",
        (f'composerData:{chat_id}',)
    )
    
    row = cursor.fetchone()
    if not row:
        return None
    
    return json.loads(row[0])


def get_chat_messages(
    conn: sqlite3.Connection,
    chat_id: str
) -> List[Tuple[str, Dict[str, Any]]]:
    """Get all messages for a specific chat
    
    Args:
        conn: SQLite connection
        chat_id: Chat UUID
        
    Returns:
        List of tuples (bubble_id, bubble_data)
    """
    cursor = conn.cursor()
    cursor.execute("""
        SELECT key, value 
        FROM cursorDiskKV 
        WHERE key LIKE ?
        ORDER BY key
    """, (f'bubbleId:{chat_id}:%',))
    
    messages = []
    for key, value_blob in cursor.fetchall():
        bubble_id = key.split(':')[-1]
        bubble_data = json.loads(value_blob)
        messages.append((bubble_id, bubble_data))
    
    return messages


def count_chats(conn: sqlite3.Connection, include_archived: bool = True) -> int:
    """Count total number of chats
    
    Args:
        conn: SQLite connection
        include_archived: Whether to include archived chats
        
    Returns:
        Total count of chats
    """
    cursor = conn.cursor()
    
    if include_archived:
        cursor.execute("""
            SELECT COUNT(*) FROM cursorDiskKV 
            WHERE key LIKE 'composerData:%'
        """)
    else:
        # Need to check each chat's metadata
        cursor.execute("""
            SELECT value FROM cursorDiskKV 
            WHERE key LIKE 'composerData:%'
        """)
        count = 0
        for (value_blob,) in cursor.fetchall():
            metadata = json.loads(value_blob)
            if not metadata.get('isArchived', False):
                count += 1
        return count
    
    return cursor.fetchone()[0]

