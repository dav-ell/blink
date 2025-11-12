"""Chat-related business logic"""

import json
import uuid as uuid_lib
from datetime import datetime
from typing import Dict, Any

from ..database import get_db_connection


def create_new_chat() -> Dict[str, Any]:
    """Create a new chat in the database
    
    Returns:
        Dict with chat_id and status
        
    Raises:
        Exception: If chat creation fails
    """
    chat_id = str(uuid_lib.uuid4())
    
    # Create minimal composerData structure
    composer_data = {
        "_v": 10,
        "composerId": chat_id,
        "name": "",
        "text": "",
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
        "fullConversationHeadersOnly": [],
        "createdAt": int(datetime.now().timestamp() * 1000),
        "lastUpdatedAt": int(datetime.now().timestamp() * 1000),
        "isArchived": False,
        "isDraft": False,
        "hasLoaded": True,
        "totalLinesAdded": 0,
        "totalLinesRemoved": 0
    }
    
    # Save to database
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute(
            "INSERT INTO cursorDiskKV (key, value) VALUES (?, ?)",
            (f'composerData:{chat_id}', json.dumps(composer_data))
        )
        conn.commit()
    finally:
        conn.close()
    
    return {
        "status": "success",
        "chat_id": chat_id,
        "message": "Chat created successfully"
    }

