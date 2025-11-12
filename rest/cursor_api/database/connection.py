"""Database connection management"""

import os
import sqlite3
from fastapi import HTTPException

from ..config import settings


def get_db_connection() -> sqlite3.Connection:
    """Get SQLite connection to Cursor database
    
    Returns:
        SQLite connection object
        
    Raises:
        HTTPException: If database file not found (503)
    """
    if not os.path.exists(settings.db_path):
        raise HTTPException(
            status_code=503,
            detail=f"Database not found at {settings.db_path}"
        )
    return sqlite3.connect(settings.db_path)

