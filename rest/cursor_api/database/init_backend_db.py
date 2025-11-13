"""
Initialize the backend Blink database with Cursor schema

This creates a standalone database that mimics Cursor's structure but is
independent of the Cursor IDE installation.
"""

import sqlite3
import os
from pathlib import Path


def get_backend_db_path() -> str:
    """Get the path to the backend database"""
    base_path = Path(__file__).parent.parent.parent / "cursor_agent_db"
    db_dir = base_path / "Library" / "Application Support" / "Cursor" / "User" / "globalStorage"
    db_dir.mkdir(parents=True, exist_ok=True)
    return str(db_dir / "state.vscdb")


def init_backend_database(db_path: str = None) -> str:
    """
    Initialize a new backend database with Cursor schema
    
    Args:
        db_path: Optional custom path. If None, uses default backend location.
        
    Returns:
        Path to the created database
    """
    if db_path is None:
        db_path = get_backend_db_path()
    
    # Create database directory if needed
    os.makedirs(os.path.dirname(db_path), exist_ok=True)
    
    # Create/connect to database
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Create tables with Cursor's schema
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS cursorDiskKV (
            key TEXT PRIMARY KEY,
            value BLOB
        ) WITHOUT ROWID
    """)
    
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS ItemTable (
            key TEXT PRIMARY KEY,
            value BLOB
        ) WITHOUT ROWID
    """)
    
    # Create indexes for better performance
    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_cursorDiskKV_key 
        ON cursorDiskKV(key)
    """)
    
    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_composerData 
        ON cursorDiskKV(key) 
        WHERE key LIKE 'composerData:%'
    """)
    
    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_bubbleId 
        ON cursorDiskKV(key) 
        WHERE key LIKE 'bubbleId:%'
    """)
    
    conn.commit()
    conn.close()
    
    return db_path


def verify_backend_database(db_path: str = None) -> bool:
    """
    Verify the backend database has correct schema
    
    Returns:
        True if database is valid, False otherwise
    """
    if db_path is None:
        db_path = get_backend_db_path()
    
    if not os.path.exists(db_path):
        return False
    
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Check tables exist
        cursor.execute("""
            SELECT name FROM sqlite_master 
            WHERE type='table' AND name IN ('cursorDiskKV', 'ItemTable')
        """)
        tables = cursor.fetchall()
        
        conn.close()
        
        return len(tables) == 2
    except Exception:
        return False


if __name__ == "__main__":
    print("Initializing Blink backend database...")
    db_path = init_backend_database()
    print(f"✓ Database created at: {db_path}")
    
    if verify_backend_database(db_path):
        print("✓ Database schema verified")
    else:
        print("✗ Database verification failed")
        exit(1)
    
    # Print database info
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("SELECT COUNT(*) FROM cursorDiskKV")
    count = cursor.fetchone()[0]
    conn.close()
    
    print(f"✓ Database ready (0 chats)")



