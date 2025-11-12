# Cursor Database - Code Examples

Complete working code examples for interacting with Cursor's database.

## Complete Bubble Creation (Python)

### Proper Bubble Structure for Cursor IDE Compatibility

```python
import json
import uuid
from datetime import datetime, timezone

def create_complete_bubble(bubble_id: str, message_type: int, text: str) -> dict:
    """
    Create a complete bubble structure with all 69+ fields required by Cursor IDE.
    
    Args:
        bubble_id: UUID for the bubble
        message_type: 1 for user, 2 for assistant
        text: Message text content
    
    Returns:
        Complete bubble dict ready for database insertion
    """
    
    # Generate unique identifiers
    request_id = str(uuid.uuid4())
    checkpoint_id = str(uuid.uuid4())
    
    # Create Lexical editor richText structure
    rich_text = {
        "root": {
            "children": [{
                "children": [{
                    "detail": 0,
                    "format": 0,
                    "mode": "normal",
                    "style": "",
                    "text": text,
                    "type": "text",
                    "version": 1
                }],
                "direction": None,
                "format": "",
                "indent": 0,
                "type": "paragraph",
                "version": 1
            }],
            "direction": None,
            "format": "",
            "indent": 0,
            "type": "root",
            "version": 1
        }
    }
    
    bubble = {
        "_v": 3,
        "type": message_type,
        "text": text,
        "bubbleId": bubble_id,
        "createdAt": datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
        
        # Core arrays (must exist, can be empty)
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
        "multiFileLinterErrors": [],
        "diffHistories": [],
        "recentLocationsHistory": [],
        "recentlyViewedFiles": [],
        "fileDiffTrajectories": [],
        "docsReferences": [],
        "webReferences": [],
        "aiWebSearchResults": [],
        "attachedFoldersListDirResults": [],
        "humanChanges": [],
        
        # Additional arrays required by Cursor
        "allThinkingBlocks": [],
        "attachedFileCodeChunksMetadataOnly": [],
        "capabilityContexts": [],
        "consoleLogs": [],
        "contextPieces": [],
        "cursorRules": [],
        "deletedFiles": [],
        "diffsForCompressingFiles": [],
        "diffsSinceLastApply": [],
        "documentationSelections": [],
        "editTrailContexts": [],
        "externalLinks": [],
        "knowledgeItems": [],
        "projectLayouts": [],
        "relevantFiles": [],
        "suggestedCodeBlocks": [],
        "summarizedComposers": [],
        "todos": [],
        "codeBlocks": [],
        "uiElementPicked": [],
        "userResponsesToSuggestedCodeBlocks": [],
        
        # Capability statuses (10 capability types)
        "capabilityStatuses": {
            "mutate-request": [],
            "start-submit-chat": [],
            "before-submit-chat": [],
            "chat-stream-finished": [],
            "before-apply": [],
            "after-apply": [],
            "accept-all-edits": [],
            "composer-done": [],
            "process-stream": [],
            "add-pending-action": []
        },
        
        # Boolean flags
        "isAgentic": message_type == 1,
        "existedSubsequentTerminalCommand": False,
        "existedPreviousTerminalCommand": False,
        "editToolSupportsSearchAndReplace": True,
        "isNudge": False,
        "isPlanExecution": False,
        "isQuickSearchQuery": False,
        "isRefunded": False,
        "skipRendering": False,
        "useWeb": False,
        
        # Critical complex fields
        "supportedTools": [1, 41, 7, 38, 8, 9, 11, 12, 15, 18, 19, 25, 27, 43, 46, 47, 29, 30, 32, 34, 35, 39, 40, 42, 44, 45],
        "tokenCount": {
            "inputTokens": 0,
            "outputTokens": 0
        },
        "context": {
            "composers": [],
            "quotes": [],
            "selectedCommits": [],
            "selectedPullRequests": [],
            "selectedImages": [],
            "folderSelections": [],
            "fileSelections": [],
            "terminalFiles": [],
            "selections": [],
            "terminalSelections": [],
            "selectedDocs": [],
            "externalLinks": [],
            "cursorRules": [],
            "cursorCommands": [],
            "uiElementSelections": [],
            "consoleLogs": [],
            "mentions": []
        },
        
        # Identifiers
        "requestId": request_id,
        "checkpointId": checkpoint_id,
        
        # Rich text (must be JSON string, not object)
        "richText": json.dumps(rich_text),
        
        # Unified mode
        "unifiedMode": 5,
        
        # Tool and thinking data
        "toolFormerData": {},
        "thinking": {},
    }
    
    # Add model info for assistant messages
    if message_type == 2:
        bubble["modelInfo"] = {
            "modelName": "claude-4.5-sonnet"
        }
    
    return bubble


# Usage example
if __name__ == "__main__":
    bubble = create_complete_bubble(
        str(uuid.uuid4()),
        1,
        "Hello from API!"
    )
    
    print(f"✓ Created bubble with {len(bubble.keys())} fields")
    print(f"✓ Has all required fields: {len(bubble.keys()) >= 69}")
    print(f"✓ Field list: {', '.join(sorted(bubble.keys()))}")
```

## Complete Composer Creation

```python
def create_composer_metadata(chat_id: str, name: str = "Untitled") -> dict:
    """
    Create complete composerData metadata with all required fields.
    
    Args:
        chat_id: UUID for the chat
        name: Chat name/title
    
    Returns:
        Complete composer metadata dict
    """
    import time
    
    now_ms = int(time.time() * 1000)
    
    # Empty richText structure for composer
    empty_rich_text = {
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
    }
    
    return {
        "_v": 10,
        "composerId": chat_id,
        "name": name,
        "richText": json.dumps(empty_rich_text),
        "hasLoaded": True,
        "text": "",
        "fullConversationHeadersOnly": [],
        "createdAt": now_ms,
        "lastUpdatedAt": now_ms,
        "isArchived": False,
        "isDraft": False,
        "totalLinesAdded": 0,
        "totalLinesRemoved": 0,
    }


# Usage
metadata = create_composer_metadata("3f1a6a8c-58d1-4fbe-81f7-1ad946d9c84e", "My New Chat")
print(f"✓ Created composer with {len(metadata.keys())} fields")
```

## Writing Messages to Database

### Complete Workflow with Safety Checks

```python
import sqlite3
import os
import json
import uuid
import time
from datetime import datetime, timezone

def write_message_to_cursor_db(
    chat_id: str, 
    message_type: int, 
    text: str,
    db_path: str = None
):
    """
    Complete example: Write a message to Cursor database with full structure.
    
    Args:
        chat_id: Chat UUID
        message_type: 1 for user, 2 for assistant
        text: Message content
        db_path: Optional custom database path
    
    Returns:
        bubble_id: UUID of created message
    """
    
    if db_path is None:
        db_path = os.path.expanduser(
            '~/Library/Application Support/Cursor/User/globalStorage/state.vscdb'
        )
    
    # Safety check
    if not os.path.exists(db_path):
        raise FileNotFoundError(f"Database not found: {db_path}")
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    try:
        # Step 1: Check if chat exists, create if not
        cursor.execute(
            "SELECT value FROM cursorDiskKV WHERE key = ?",
            (f'composerData:{chat_id}',)
        )
        
        result = cursor.fetchone()
        if not result:
            print(f"⚠ Chat {chat_id} doesn't exist, creating...")
            metadata = create_composer_metadata(chat_id)
            cursor.execute(
                "INSERT INTO cursorDiskKV (key, value) VALUES (?, ?)",
                (f'composerData:{chat_id}', json.dumps(metadata))
            )
        
        # Step 2: Create bubble with complete structure
        bubble_id = str(uuid.uuid4())
        bubble = create_complete_bubble(bubble_id, message_type, text)
        
        # Validate before write
        if len(bubble.keys()) < 69:
            raise ValueError(f"Incomplete bubble: only {len(bubble.keys())} fields")
        
        # Step 3: Write bubble to database
        cursor.execute(
            "INSERT INTO cursorDiskKV (key, value) VALUES (?, ?)",
            (f'bubbleId:{chat_id}:{bubble_id}', json.dumps(bubble))
        )
        
        # Step 4: Update composer metadata
        cursor.execute(
            "SELECT value FROM cursorDiskKV WHERE key = ?",
            (f'composerData:{chat_id}',)
        )
        metadata = json.loads(cursor.fetchone()[0])
        
        # Add to conversation history
        metadata['fullConversationHeadersOnly'].append({
            "bubbleId": bubble_id,
            "type": message_type
        })
        
        # Update timestamp
        metadata['lastUpdatedAt'] = int(time.time() * 1000)
        
        cursor.execute(
            "UPDATE cursorDiskKV SET value = ? WHERE key = ?",
            (json.dumps(metadata), f'composerData:{chat_id}')
        )
        
        # Commit all changes
        conn.commit()
        
        print(f"✓ Message written successfully")
        print(f"  Chat ID: {chat_id}")
        print(f"  Bubble ID: {bubble_id}")
        print(f"  Type: {'User' if message_type == 1 else 'Assistant'}")
        print(f"  Fields: {len(bubble.keys())}")
        
        return bubble_id
        
    except Exception as e:
        conn.rollback()
        print(f"✗ Error writing message: {e}")
        raise
    finally:
        conn.close()


# Usage
if __name__ == "__main__":
    chat_id = "3f1a6a8c-58d1-4fbe-81f7-1ad946d9c84e"
    bubble_id = write_message_to_cursor_db(
        chat_id,
        1,  # User message
        "Hello! This is a test message."
    )
```

## Auto-Create Pattern

### Ensure Chat Exists Before Writing

```python
def ensure_chat_exists(chat_id: str, cursor, conn) -> bool:
    """
    Create composerData entry if it doesn't exist.
    
    This solves the issue where cursor-agent create-chat generates
    a UUID but doesn't create the database entry.
    
    Args:
        chat_id: Chat UUID
        cursor: Database cursor
        conn: Database connection
    
    Returns:
        True if chat was created, False if it already existed
    """
    cursor.execute(
        "SELECT value FROM cursorDiskKV WHERE key = ?",
        (f'composerData:{chat_id}',)
    )
    
    if not cursor.fetchone():
        print(f"⚠ Creating missing composerData entry for {chat_id}")
        
        # Create minimal composer metadata
        metadata = create_composer_metadata(chat_id, "New Chat")
        
        cursor.execute(
            "INSERT INTO cursorDiskKV (key, value) VALUES (?, ?)",
            (f'composerData:{chat_id}', json.dumps(metadata))
        )
        
        conn.commit()
        return True
    
    return False


# Usage in REST API endpoint
@app.post("/agent/send-prompt")
def send_agent_prompt(chat_id: str, prompt: str):
    """Send prompt to cursor-agent."""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        # Auto-create if missing
        was_created = ensure_chat_exists(chat_id, cursor, conn)
        if was_created:
            print(f"✓ Auto-created chat {chat_id}")
        
        # Proceed with sending message
        # ... rest of endpoint logic
        
    finally:
        conn.close()
```

## Validating Bubble Structure

### Check for Missing Fields

```python
def validate_bubble_structure(bubble: dict) -> tuple[bool, list[str]]:
    """
    Validate that a bubble has all required fields for Cursor IDE.
    
    Returns:
        (is_valid, missing_fields)
    """
    required_fields = {
        # Version and core
        "_v", "type", "text", "bubbleId", "createdAt",
        
        # Identifiers
        "requestId", "checkpointId",
        
        # Critical complex fields
        "supportedTools", "tokenCount", "context", "richText",
        "capabilityStatuses", "toolFormerData", "thinking",
        
        # Flags
        "isAgentic", "unifiedMode",
        "editToolSupportsSearchAndReplace",
        "existedSubsequentTerminalCommand",
        "existedPreviousTerminalCommand",
        "isNudge", "isPlanExecution",
        "isQuickSearchQuery", "isRefunded",
        "skipRendering", "useWeb",
        
        # Arrays (must exist, can be empty)
        "approximateLintErrors", "lints", "capabilities",
        "allThinkingBlocks", "todos", "codeBlocks",
        "codebaseContextChunks", "commits", "pullRequests",
        "attachedCodeChunks", "assistantSuggestedDiffs",
        "gitDiffs", "interpreterResults", "images",
        "attachedFolders", "attachedFoldersNew",
        "toolResults", "notepads",
        "multiFileLinterErrors", "diffHistories",
        "recentLocationsHistory", "recentlyViewedFiles",
        "fileDiffTrajectories", "docsReferences",
        "webReferences", "aiWebSearchResults",
        "attachedFoldersListDirResults", "humanChanges",
        "attachedFileCodeChunksMetadataOnly",
        "capabilityContexts", "consoleLogs", "contextPieces",
        "cursorRules", "deletedFiles", "diffsForCompressingFiles",
        "diffsSinceLastApply", "documentationSelections",
        "editTrailContexts", "externalLinks", "knowledgeItems",
        "projectLayouts", "relevantFiles", "suggestedCodeBlocks",
        "summarizedComposers", "uiElementPicked",
        "userResponsesToSuggestedCodeBlocks",
    }
    
    missing = required_fields - set(bubble.keys())
    return len(missing) == 0, sorted(list(missing))


def compare_bubble_field_count(bubble: dict) -> dict:
    """
    Analyze bubble structure completeness.
    """
    field_count = len(bubble.keys())
    
    return {
        "field_count": field_count,
        "is_minimal": field_count < 30,
        "is_complete": field_count >= 69,
        "status": (
            "✗ Too few fields - will break Cursor IDE" if field_count < 30
            else "⚠ Missing some fields" if field_count < 69
            else "✓ Complete structure"
        )
    }


# Usage
bubble = create_complete_bubble(str(uuid.uuid4()), 1, "Test")
is_valid, missing = validate_bubble_structure(bubble)
analysis = compare_bubble_field_count(bubble)

print(f"Valid: {is_valid}")
print(f"Status: {analysis['status']}")
if missing:
    print(f"Missing fields: {', '.join(missing)}")
```

## Reading from Database

### Query Chat Messages

```python
def get_chat_messages(chat_id: str, db_path: str = None) -> list[dict]:
    """
    Get all messages for a specific chat.
    
    Args:
        chat_id: Chat UUID
        db_path: Optional custom database path
    
    Returns:
        List of message dicts, sorted by creation time
    """
    if db_path is None:
        db_path = os.path.expanduser(
            '~/Library/Application Support/Cursor/User/globalStorage/state.vscdb'
        )
    
    # Use read-only mode for safety
    conn = sqlite3.connect(f'file:{db_path}?mode=ro', uri=True)
    cursor = conn.cursor()
    
    try:
        cursor.execute("""
            SELECT key, value 
            FROM cursorDiskKV 
            WHERE key LIKE ?
            ORDER BY json_extract(value, '$.createdAt')
        """, (f'bubbleId:{chat_id}:%',))
        
        messages = []
        for key, value_blob in cursor.fetchall():
            bubble = json.loads(value_blob)
            messages.append({
                'id': bubble['bubbleId'],
                'type': 'user' if bubble['type'] == 1 else 'assistant',
                'text': bubble.get('text', ''),
                'createdAt': bubble.get('createdAt'),
                'field_count': len(bubble.keys())
            })
        
        return messages
        
    finally:
        conn.close()


# Usage
messages = get_chat_messages("3f1a6a8c-58d1-4fbe-81f7-1ad946d9c84e")
for msg in messages:
    print(f"{msg['type']}: {msg['text'][:50]}... ({msg['field_count']} fields)")
```

### List All Chats

```python
def list_all_chats(db_path: str = None) -> list[dict]:
    """
    List all chats in the database.
    
    Returns:
        List of chat metadata dicts, sorted by last update
    """
    if db_path is None:
        db_path = os.path.expanduser(
            '~/Library/Application Support/Cursor/User/globalStorage/state.vscdb'
        )
    
    conn = sqlite3.connect(f'file:{db_path}?mode=ro', uri=True)
    cursor = conn.cursor()
    
    try:
        cursor.execute("""
            SELECT value 
            FROM cursorDiskKV 
            WHERE key LIKE 'composerData:%'
            ORDER BY json_extract(value, '$.lastUpdatedAt') DESC
        """)
        
        chats = []
        for (value_blob,) in cursor.fetchall():
            composer = json.loads(value_blob)
            chats.append({
                'id': composer['composerId'],
                'name': composer.get('name', 'Untitled'),
                'createdAt': composer.get('createdAt'),
                'lastUpdatedAt': composer.get('lastUpdatedAt'),
                'messageCount': len(composer.get('fullConversationHeadersOnly', [])),
                'isArchived': composer.get('isArchived', False)
            })
        
        return chats
        
    finally:
        conn.close()


# Usage
chats = list_all_chats()
for chat in chats:
    print(f"{chat['name']} ({chat['messageCount']} messages)")
```

## Repairing Broken Chats

### Fix Incomplete Bubble Structures

```python
def repair_bubble(incomplete_bubble: dict) -> dict:
    """
    Take an incomplete bubble and fill in all missing required fields.
    
    Args:
        incomplete_bubble: Partial bubble dict
    
    Returns:
        Complete bubble dict with all 69+ fields
    """
    # Create a complete template
    template = create_complete_bubble(
        incomplete_bubble.get('bubbleId', str(uuid.uuid4())),
        incomplete_bubble.get('type', 1),
        incomplete_bubble.get('text', '')
    )
    
    # Preserve original values, fill in missing with template
    repaired = template.copy()
    
    for key, value in incomplete_bubble.items():
        # Keep original values for these fields
        if key in ['bubbleId', 'type', 'text', 'createdAt']:
            repaired[key] = value
        # For arrays, keep if not empty
        elif isinstance(value, list) and len(value) > 0:
            repaired[key] = value
        # For objects, merge
        elif isinstance(value, dict) and key in ['context', 'tokenCount']:
            repaired[key].update(value)
    
    return repaired


def repair_chat_in_database(chat_id: str, db_path: str = None, dry_run: bool = True):
    """
    Repair all messages in a chat by filling in missing fields.
    
    Args:
        chat_id: Chat UUID
        db_path: Database path
        dry_run: If True, only report issues without fixing
    """
    if db_path is None:
        db_path = os.path.expanduser(
            '~/Library/Application Support/Cursor/User/globalStorage/state.vscdb'
        )
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    try:
        # Get all bubbles for this chat
        cursor.execute("""
            SELECT key, value 
            FROM cursorDiskKV 
            WHERE key LIKE ?
        """, (f'bubbleId:{chat_id}:%',))
        
        repairs_needed = 0
        
        for key, value_blob in cursor.fetchall():
            bubble = json.loads(value_blob)
            field_count = len(bubble.keys())
            
            if field_count < 69:
                repairs_needed += 1
                print(f"⚠ {key}: {field_count} fields (needs repair)")
                
                if not dry_run:
                    # Repair the bubble
                    repaired = repair_bubble(bubble)
                    
                    # Update in database
                    cursor.execute(
                        "UPDATE cursorDiskKV SET value = ? WHERE key = ?",
                        (json.dumps(repaired), key)
                    )
                    
                    print(f"  ✓ Repaired: now has {len(repaired.keys())} fields")
            else:
                print(f"✓ {key}: {field_count} fields (complete)")
        
        if not dry_run and repairs_needed > 0:
            conn.commit()
            print(f"\n✓ Repaired {repairs_needed} bubbles")
        elif repairs_needed > 0:
            print(f"\n⚠ {repairs_needed} bubbles need repair (use dry_run=False to fix)")
        else:
            print("\n✓ All bubbles are complete!")
        
    except Exception as e:
        conn.rollback()
        print(f"✗ Error: {e}")
        raise
    finally:
        conn.close()


# Usage
# Check what needs repair
repair_chat_in_database("3f1a6a8c-58d1-4fbe-81f7-1ad946d9c84e", dry_run=True)

# Actually repair
repair_chat_in_database("3f1a6a8c-58d1-4fbe-81f7-1ad946d9c84e", dry_run=False)
```

## Database Backup and Restore

### Safe Backup Procedure

```python
import shutil
from datetime import datetime

def backup_cursor_database(backup_dir: str = None) -> str:
    """
    Create a timestamped backup of the Cursor database.
    
    Args:
        backup_dir: Optional custom backup directory
    
    Returns:
        Path to backup file
    """
    db_path = os.path.expanduser(
        '~/Library/Application Support/Cursor/User/globalStorage/state.vscdb'
    )
    
    if backup_dir is None:
        backup_dir = os.path.dirname(db_path)
    
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    backup_path = os.path.join(backup_dir, f'state.vscdb.{timestamp}.backup')
    
    try:
        shutil.copy2(db_path, backup_path)
        backup_size = os.path.getsize(backup_path)
        print(f"✓ Backup created: {backup_path}")
        print(f"  Size: {backup_size / 1024 / 1024:.2f} MB")
        return backup_path
    except Exception as e:
        print(f"✗ Backup failed: {e}")
        raise


def restore_cursor_database(backup_path: str):
    """
    Restore database from backup.
    
    WARNING: This will overwrite the current database!
    """
    db_path = os.path.expanduser(
        '~/Library/Application Support/Cursor/User/globalStorage/state.vscdb'
    )
    
    if not os.path.exists(backup_path):
        raise FileNotFoundError(f"Backup not found: {backup_path}")
    
    try:
        # Create safety backup of current state
        safety_backup = f"{db_path}.before_restore.backup"
        shutil.copy2(db_path, safety_backup)
        print(f"✓ Safety backup: {safety_backup}")
        
        # Restore from backup
        shutil.copy2(backup_path, db_path)
        print(f"✓ Database restored from: {backup_path}")
        
    except Exception as e:
        print(f"✗ Restore failed: {e}")
        raise


# Usage
# Before any risky operation
backup_path = backup_cursor_database()

# If something goes wrong
restore_cursor_database(backup_path)
```

## Cleaning Malformed Arrays

### Fix Type Errors in Array Fields

```python
def clean_array_fields(bubble: dict) -> dict:
    """
    Remove non-dict items from array fields that should contain objects.
    
    This fixes the "String is not a subtype of Map<String, dynamic>" error
    that occurs when older Cursor bubbles have string items in todos/codeBlocks.
    
    Args:
        bubble: Bubble dict possibly containing malformed arrays
    
    Returns:
        Cleaned bubble dict
    """
    array_fields_requiring_objects = ['todos', 'codeBlocks', 'capabilities']
    
    for field in array_fields_requiring_objects:
        if field in bubble and isinstance(bubble[field], list):
            # Filter out non-dict items
            original_count = len(bubble[field])
            bubble[field] = [
                item for item in bubble[field] 
                if isinstance(item, dict)
            ]
            
            removed = original_count - len(bubble[field])
            if removed > 0:
                print(f"⚠ Removed {removed} malformed items from {field}")
    
    return bubble


# Usage in API endpoint
@app.get("/chat/{chat_id}/messages")
def get_messages(chat_id: str):
    """Get messages with cleaned arrays."""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT value FROM cursorDiskKV 
        WHERE key LIKE ?
    """, (f'bubbleId:{chat_id}:%',))
    
    messages = []
    for (value_blob,) in cursor.fetchall():
        bubble = json.loads(value_blob)
        
        # Clean arrays before sending to client
        bubble = clean_array_fields(bubble)
        
        messages.append(bubble)
    
    return {"messages": messages}
```

## See Also

- Main skill documentation: [SKILL.md](SKILL.md)
- REST API implementation: `/Users/davell/Documents/github/blink/rest/cursor_chat_api.py`
- Investigation scripts: `/Users/davell/Documents/github/blink/rest/scripts/`
- cursor-internals skill: `/Users/davell/Documents/github/blink/.claude/skills/cursor-internals/SKILL.md`

