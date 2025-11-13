"""
Database synchronization utilities for cursor-agent resume functionality

This module handles syncing chat data between:
- Backend DB (standalone): Where Blink stores its data
- System DB (Cursor IDE): Where cursor-agent reads/writes data

The sync flow:
1. Before cursor-agent call: Copy chat from backend → system
2. After cursor-agent call: Copy updated chat from system → backend
"""

import sqlite3
import logging
from typing import Optional

from .connection import get_backend_db_connection, get_cursor_ide_db_connection

logger = logging.getLogger(__name__)


def sync_chat_to_system_db(chat_id: str) -> bool:
    """
    Sync a chat from standalone backend DB to system Cursor DB
    
    This prepares the system DB so cursor-agent can use --resume to access
    the chat history.
    
    Args:
        chat_id: The chat/composer ID to sync
        
    Returns:
        True if sync was successful, False otherwise
    """
    backend_conn = None
    system_conn = None
    
    try:
        backend_conn = get_backend_db_connection()
        system_conn = get_cursor_ide_db_connection()
        
        backend_cursor = backend_conn.cursor()
        system_cursor = system_conn.cursor()
        
        # 1. Sync composerData
        composer_key = f'composerData:{chat_id}'
        backend_cursor.execute(
            "SELECT value FROM cursorDiskKV WHERE key = ?",
            (composer_key,)
        )
        composer_row = backend_cursor.fetchone()
        
        if composer_row:
            logger.info(f"Syncing composerData for chat {chat_id} to system DB")
            system_cursor.execute(
                "INSERT OR REPLACE INTO cursorDiskKV (key, value) VALUES (?, ?)",
                (composer_key, composer_row[0])
            )
        else:
            logger.warning(f"No composerData found for chat {chat_id} in backend DB")
            return False
        
        # 2. Sync all bubbles (messages) for this chat
        bubble_pattern = f'bubbleId:{chat_id}:%'
        backend_cursor.execute(
            "SELECT key, value FROM cursorDiskKV WHERE key LIKE ?",
            (bubble_pattern,)
        )
        
        bubble_count = 0
        for key, value in backend_cursor.fetchall():
            system_cursor.execute(
                "INSERT OR REPLACE INTO cursorDiskKV (key, value) VALUES (?, ?)",
                (key, value)
            )
            bubble_count += 1
        
        logger.info(f"Synced {bubble_count} bubbles for chat {chat_id} to system DB")
        
        # Commit changes
        system_conn.commit()
        
        return True
        
    except Exception as e:
        logger.error(f"Failed to sync chat {chat_id} to system DB: {e}")
        if system_conn:
            system_conn.rollback()
        return False
        
    finally:
        if backend_conn:
            backend_conn.close()
        if system_conn:
            system_conn.close()


def sync_chat_from_system_db(chat_id: str) -> bool:
    """
    Sync a chat from system Cursor DB back to standalone backend DB
    
    This captures any updates made by cursor-agent (new messages, metadata changes)
    and brings them back to the backend DB.
    
    Args:
        chat_id: The chat/composer ID to sync
        
    Returns:
        True if sync was successful, False otherwise
    """
    backend_conn = None
    system_conn = None
    
    try:
        system_conn = get_cursor_ide_db_connection()
        backend_conn = get_backend_db_connection()
        
        system_cursor = system_conn.cursor()
        backend_cursor = backend_conn.cursor()
        
        # 1. Sync composerData
        composer_key = f'composerData:{chat_id}'
        system_cursor.execute(
            "SELECT value FROM cursorDiskKV WHERE key = ?",
            (composer_key,)
        )
        composer_row = system_cursor.fetchone()
        
        if composer_row:
            logger.info(f"Syncing composerData for chat {chat_id} from system DB")
            backend_cursor.execute(
                "INSERT OR REPLACE INTO cursorDiskKV (key, value) VALUES (?, ?)",
                (composer_key, composer_row[0])
            )
        else:
            logger.warning(f"No composerData found for chat {chat_id} in system DB")
            # Don't return False - might just be a new chat
        
        # 2. Sync all bubbles (messages) for this chat
        bubble_pattern = f'bubbleId:{chat_id}:%'
        system_cursor.execute(
            "SELECT key, value FROM cursorDiskKV WHERE key LIKE ?",
            (bubble_pattern,)
        )
        
        bubble_count = 0
        for key, value in system_cursor.fetchall():
            backend_cursor.execute(
                "INSERT OR REPLACE INTO cursorDiskKV (key, value) VALUES (?, ?)",
                (key, value)
            )
            bubble_count += 1
        
        logger.info(f"Synced {bubble_count} bubbles for chat {chat_id} from system DB")
        
        # Commit changes
        backend_conn.commit()
        
        return True
        
    except Exception as e:
        logger.error(f"Failed to sync chat {chat_id} from system DB: {e}")
        if backend_conn:
            backend_conn.rollback()
        return False
        
    finally:
        if system_conn:
            system_conn.close()
        if backend_conn:
            backend_conn.close()


def ensure_chat_synced_for_resume(chat_id: str) -> bool:
    """
    Ensure a chat is available in system DB for cursor-agent --resume
    
    This is a convenience function that checks if sync is needed and performs it.
    
    Args:
        chat_id: The chat/composer ID
        
    Returns:
        True if chat is ready for resume, False otherwise
    """
    return sync_chat_to_system_db(chat_id)


def sync_chat_after_agent_run(chat_id: str) -> bool:
    """
    Sync chat back to backend DB after cursor-agent has modified it
    
    Args:
        chat_id: The chat/composer ID
        
    Returns:
        True if sync was successful, False otherwise
    """
    return sync_chat_from_system_db(chat_id)



