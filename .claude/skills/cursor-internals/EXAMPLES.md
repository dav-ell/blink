# Cursor Internals - Code Examples

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
        
        # Core arrays
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
        "uiElementPicked": [],
        "userResponsesToSuggestedCodeBlocks": [],
        
        # Capability statuses
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
        
        # Critical fields
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
        
        # Rich text
        "richText": json.dumps(rich_text),
        
        # Unified mode
        "unifiedMode": 5,
    }
    
    # Add model info for assistant messages
    if message_type == 2:
        bubble["modelInfo"] = {
            "modelName": "claude-4.5-sonnet"
        }
    
    return bubble


def create_composer_metadata(chat_id: str, name: str = "Untitled") -> dict:
    """
    Create complete composerData metadata with all required fields.
    
    Args:
        chat_id: UUID for the chat
        name: Chat name/title
    
    Returns:
        Complete composer metadata dict
    """
    now_ms = int(datetime.now().timestamp() * 1000)
    
    return {
        "_v": 10,
        "composerId": chat_id,
        "name": name,
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


def write_message_to_cursor_db(chat_id: str, message_type: int, text: str):
    """
    Complete example: Write a message to Cursor database with full structure.
    """
    import sqlite3
    import os
    
    db_path = os.path.expanduser(
        '~/Library/Application Support/Cursor/User/globalStorage/state.vscdb'
    )
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    try:
        # Check if chat exists, create if not
        cursor.execute(
            "SELECT value FROM cursorDiskKV WHERE key = ?",
            (f'composerData:{chat_id}',)
        )
        
        if not cursor.fetchone():
            # Create composer metadata
            metadata = create_composer_metadata(chat_id)
            cursor.execute(
                "INSERT INTO cursorDiskKV (key, value) VALUES (?, ?)",
                (f'composerData:{chat_id}', json.dumps(metadata))
            )
        
        # Create bubble
        bubble_id = str(uuid.uuid4())
        bubble = create_complete_bubble(bubble_id, message_type, text)
        
        # Write bubble
        cursor.execute(
            "INSERT INTO cursorDiskKV (key, value) VALUES (?, ?)",
            (f'bubbleId:{chat_id}:{bubble_id}', json.dumps(bubble))
        )
        
        # Update composer metadata
        cursor.execute(
            "SELECT value FROM cursorDiskKV WHERE key = ?",
            (f'composerData:{chat_id}',)
        )
        metadata = json.loads(cursor.fetchone()[0])
        metadata['fullConversationHeadersOnly'].append({
            "bubbleId": bubble_id,
            "type": message_type
        })
        metadata['lastUpdatedAt'] = int(datetime.now().timestamp() * 1000)
        
        cursor.execute(
            "UPDATE cursorDiskKV SET value = ? WHERE key = ?",
            (json.dumps(metadata), f'composerData:{chat_id}')
        )
        
        conn.commit()
        print(f"✓ Message written: {bubble_id}")
        
    except Exception as e:
        conn.rollback()
        print(f"✗ Error: {e}")
        raise
    finally:
        conn.close()


# Usage
if __name__ == "__main__":
    # Example: Create a complete bubble
    bubble = create_complete_bubble(
        str(uuid.uuid4()),
        1,
        "Hello from API!"
    )
    
    print(f"Created bubble with {len(bubble.keys())} fields")
    print(f"Has all required fields: {len(bubble.keys()) >= 69}")
```

## Validating Bubble Structure

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
        "capabilityStatuses",
        
        # Flags
        "isAgentic", "unifiedMode",
        "editToolSupportsSearchAndReplace",
        "existedSubsequentTerminalCommand",
        "existedPreviousTerminalCommand",
        
        # Arrays (must exist, can be empty)
        "approximateLintErrors", "lints", "capabilities",
        "allThinkingBlocks", "todos", "supportedTools",
        # ... (21+ more arrays)
    }
    
    missing = required_fields - set(bubble.keys())
    return len(missing) == 0, list(missing)


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
```

## Working with cursor-agent CLI

```python
import subprocess
import json

def create_chat_with_cursor_agent() -> str:
    """
    Create a new chat using cursor-agent CLI.
    Note: This only generates an ID, doesn't create database entry.
    """
    result = subprocess.run(
        ["cursor-agent", "create-chat"],
        capture_output=True,
        text=True,
        timeout=10
    )
    
    if result.returncode == 0:
        chat_id = result.stdout.strip()
        print(f"✓ Chat ID generated: {chat_id}")
        print("⚠ Note: Database entry not created yet")
        return chat_id
    else:
        raise Exception(f"Failed to create chat: {result.stderr}")


def send_message_with_cursor_agent(chat_id: str, prompt: str) -> str:
    """
    Send a message using cursor-agent (includes chat history automatically).
    """
    result = subprocess.run(
        [
            "cursor-agent",
            "--print",
            "--force",
            "--resume", chat_id,
            prompt
        ],
        capture_output=True,
        text=True,
        timeout=60
    )
    
    if result.returncode == 0:
        response = result.stdout.strip()
        print(f"✓ Response received ({len(response)} chars)")
        return response
    else:
        raise Exception(f"cursor-agent failed: {result.stderr}")


# Complete workflow
def cursor_agent_workflow():
    """
    Complete example of cursor-agent workflow with database handling.
    """
    import sqlite3
    import os
    
    # Step 1: Generate chat ID
    chat_id = create_chat_with_cursor_agent()
    
    # Step 2: Create database entry (cursor-agent doesn't do this)
    db_path = os.path.expanduser(
        '~/Library/Application Support/Cursor/User/globalStorage/state.vscdb'
    )
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Check if entry exists
    cursor.execute(
        "SELECT value FROM cursorDiskKV WHERE key = ?",
        (f'composerData:{chat_id}',)
    )
    
    if not cursor.fetchone():
        print("⚠ Creating database entry (not done by create-chat)")
        metadata = create_composer_metadata(chat_id)
        cursor.execute(
            "INSERT INTO cursorDiskKV (key, value) VALUES (?, ?)",
            (f'composerData:{chat_id}', json.dumps(metadata))
        )
        conn.commit()
    
    conn.close()
    
    # Step 3: Send message (this will work now)
    response = send_message_with_cursor_agent(
        chat_id,
        "Hello! This is a test message."
    )
    
    print(f"✓ Complete workflow succeeded")
    print(f"  Chat ID: {chat_id}")
    print(f"  Response: {response[:100]}...")
```

## See Also

- Main skill documentation: [SKILL.md](SKILL.md)
- REST API implementation: `/Users/davell/Documents/github/blink/rest/cursor_chat_api.py`
- Investigation scripts: `/Users/davell/Documents/github/blink/rest/scripts/`
- Investigation summary: `/Users/davell/Documents/github/blink/rest/scripts/INVESTIGATION_SUMMARY.md`

