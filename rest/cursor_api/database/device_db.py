"""Device database connection and initialization"""

import os
import sqlite3
from pathlib import Path
from typing import Optional

from ..config import settings


def get_device_db_path() -> str:
    """Get the device database path, expanding user home directory"""
    return os.path.expanduser(settings.device_db_path)


def init_device_db() -> None:
    """Initialize device database with schema if it doesn't exist"""
    db_path = get_device_db_path()
    
    # Create directory if it doesn't exist
    db_dir = os.path.dirname(db_path)
    if db_dir and not os.path.exists(db_dir):
        os.makedirs(db_dir, exist_ok=True)
    
    # Connect and create schema
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Read schema file
    schema_path = Path(__file__).parent.parent.parent / "device_schema.sql"
    with open(schema_path, 'r') as f:
        schema_sql = f.read()
    
    # Execute schema
    cursor.executescript(schema_sql)
    conn.commit()
    conn.close()


def get_device_db_connection() -> sqlite3.Connection:
    """Get a connection to the device database
    
    Returns:
        SQLite connection to device database
        
    Raises:
        FileNotFoundError: If database doesn't exist and can't be created
    """
    db_path = get_device_db_path()
    
    # Initialize database if it doesn't exist
    if not os.path.exists(db_path):
        init_device_db()
    
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row  # Enable column access by name
    return conn


def ensure_device_db_initialized() -> None:
    """Ensure device database is initialized (called at startup)"""
    try:
        init_device_db()
    except Exception as e:
        print(f"Warning: Failed to initialize device database: {e}")

