# Blink API Development Skill

## Purpose
Specialized skill for developing and extending the FastAPI REST backend that interfaces with Cursor's SQLite database.

## When to Use
- Adding new REST API endpoints
- Modifying database queries
- Debugging API connectivity issues
- Understanding the Cursor database schema

## Quick Start

### File to Edit
`rest/cursor_chat_api.py` - Main API server

### Starting the Server
```bash
cd rest
python3 cursor_chat_api.py
# Runs on http://localhost:8000
# Docs at http://localhost:8000/docs
```

## Database Schema

### Tables
**cursorDiskKV**:
```sql
Key patterns:
- composerData:{uuid}        # Chat metadata
- bubbleId:{composer}:{uuid} # Individual messages
```

**ItemTable**:
- Key: `workbench.panel.aichat.view.aichat.chatdata`
- Contains active chat panel state

### Data Structure

**Composer (Chat) JSON**:
```python
{
    "composerId": "uuid",
    "name": "Chat title",
    "createdAt": 1731348502000,  # Unix epoch ms
    "lastUpdatedAt": 1731349142000,
    "isArchived": false,
    "isDraft": false,
    "totalLinesAdded": 86,
    "totalLinesRemoved": 1,
    "contextUsagePercent": 11.22,
    "fullConversationHeadersOnly": [
        {"bubbleId": "uuid", "type": 1}
    ]
}
```

**Bubble (Message) JSON**:
```python
{
    "_v": 10,
    "type": 1,  # 1=user, 2=assistant
    "bubbleId": "uuid",
    "text": "Message content",
    "createdAt": "2025-11-11T17:55:02.297Z",
    "toolFormerData": {},    # Tool calls
    "thinking": {},          # Reasoning
    "codeBlocks": [],        # Code snippets
    "todos": []              # Todo items
}
```

## Adding a New Endpoint

### Pattern
```python
@app.get("/your-endpoint")
def your_endpoint(
    param: str = Query("default", description="Param description")
):
    """
    Endpoint description for auto-docs
    """
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        # 1. Query database
        cursor.execute("""
            SELECT key, value 
            FROM cursorDiskKV 
            WHERE key LIKE ?
        """, (f'pattern:{param}%',))
        
        # 2. Parse results
        results = []
        for key, value_blob in cursor.fetchall():
            data = json.loads(value_blob)
            results.append(data)
        
        # 3. Return JSON
        return {
            "count": len(results),
            "data": results
        }
        
    finally:
        conn.close()
```

### Helper Functions Available

**get_db_connection()**:
- Returns SQLite connection
- Throws `HTTPException(503)` if database not found

**parse_timestamp(ts_value)**:
- Converts Unix epoch ms to ISO string
- Handles both int and string inputs

**extract_message_content(bubble)**:
- Extracts all content from a message
- Includes text, tool calls, thinking, code blocks

## Common Query Patterns

### Get All Chats
```python
cursor.execute("""
    SELECT key, value 
    FROM cursorDiskKV 
    WHERE key LIKE 'composerData:%'
""")
```

### Get Chat Messages
```python
cursor.execute("""
    SELECT key, value 
    FROM cursorDiskKV 
    WHERE key LIKE ?
    ORDER BY key
""", (f'bubbleId:{chat_id}:%',))
```

### Get Specific Chat
```python
cursor.execute("""
    SELECT value 
    FROM cursorDiskKV 
    WHERE key = ?
""", (f'composerData:{chat_id}',))
```

## Response Structure Standards

### Always Include
```python
{
    "total": int,           # Total count
    "returned": int,        # Items in response
    "offset": int,          # Pagination offset
    "data": [...],          # Actual data
}
```

### Error Responses
```python
raise HTTPException(
    status_code=404,
    detail="Resource not found"
)
```

## Testing

### Manual Testing
```bash
# Health check
curl http://localhost:8000/health

# Get chats
curl "http://localhost:8000/chats?limit=5"

# Get specific chat
curl http://localhost:8000/chats/{chat_id}
```

### Automated Testing
```bash
cd rest
python3 test_api.py
```

## CORS Configuration
Already configured to allow all origins:
```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

## Safety Notes

### Read Operations
- Safe to run while Cursor is open
- Use SELECT queries only

### Write Operations (Disabled by Default)
```python
@app.post("/chats/{chat_id}/messages")
def send_message(
    chat_id: str,
    message: MessageCreate,
    enable_write: bool = Query(False)
):
    if not enable_write:
        raise HTTPException(403, detail="Write operations disabled")
    # ... write logic
```

⚠️ **Never write to database while Cursor is running**

## Performance Tips

1. **Use Pagination**: Always support `limit` and `offset`
2. **JSON Parse Once**: Parse blob once, extract what you need
3. **Close Connections**: Use `try/finally` pattern
4. **Index Queries**: Use key patterns efficiently

## Debugging

### Enable Verbose Logging
Run with uvicorn directly:
```bash
uvicorn cursor_chat_api:app --reload --log-level debug
```

### Check Database
```bash
sqlite3 ~/Library/Application\ Support/Cursor/User/globalStorage/state.vscdb
.tables
.schema cursorDiskKV
SELECT key FROM cursorDiskKV WHERE key LIKE 'composerData:%' LIMIT 5;
```

### Common Issues

**"Database not found"**:
- Check `DB_PATH` in `cursor_chat_api.py`
- Verify Cursor is installed
- Check path: `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`

**"No data returned"**:
- Check key patterns (case-sensitive)
- Verify data exists in database
- Check WHERE clause logic

**JSON decode errors**:
- Wrap in try/except: `json.loads(value_blob)`
- Some values might not be valid JSON

## API Documentation
Auto-generated at http://localhost:8000/docs (Swagger UI)

## Quick Reference

### Import Statements
```python
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
import sqlite3
import json
from datetime import datetime
```

### Status Codes
- 200: Success
- 404: Not found
- 503: Service unavailable (DB error)
- 500: Internal server error

