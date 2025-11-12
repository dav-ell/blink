# Cursor Database Skill

## Purpose
Specialized knowledge of Cursor IDE's internal SQLite database structure, including complete schemas, required field specifications, and best practices for database operations that maintain IDE compatibility.

## When to Use
- Working directly with Cursor's state.vscdb database
- Understanding complete chat and message data structures
- Ensuring API-created chats load properly in Cursor IDE
- Troubleshooting chat loading issues
- Implementing database write operations
- Validating bubble/composer structure completeness
- Repairing broken chats with incomplete fields

## Quick Start

### Database Location

**macOS:**
```
~/Library/Application Support/Cursor/User/globalStorage/state.vscdb
```

**Linux:**
```
~/.config/Cursor/User/globalStorage/state.vscdb
```

**Windows:**
```
%APPDATA%\Cursor\User\globalStorage\state.vscdb
```

### Quick Access

```bash
# Open database
sqlite3 ~/Library/Application\ Support/Cursor/User/globalStorage/state.vscdb

# List all chats
SELECT key FROM cursorDiskKV WHERE key LIKE 'composerData:%';

# Get messages for a chat
SELECT key FROM cursorDiskKV WHERE key LIKE 'bubbleId:YOUR_CHAT_ID:%';
```

## Database Schema

### Tables

**cursorDiskKV** - Main key-value store:
```sql
CREATE TABLE cursorDiskKV (
    key TEXT PRIMARY KEY,
    value BLOB
);
```

**ItemTable** - Active panel state:
```sql
CREATE TABLE ItemTable (
    key TEXT PRIMARY KEY,
    value TEXT
);
```

### Key Patterns in cursorDiskKV

```
composerData:{uuid}        -- Chat metadata (composer)
bubbleId:{composer}:{uuid} -- Individual messages (bubbles)
```

**Examples:**
```
composerData:3f1a6a8c-58d1-4fbe-81f7-1ad946d9c84e
bubbleId:3f1a6a8c-58d1-4fbe-81f7-1ad946d9c84e:7b2c8d9e-4f3a-11ec-9bbc-0242ac130002
```

### Value Storage

- Values stored as BLOB (binary)
- Content is JSON encoded as UTF-8
- Parse with: `json.loads(value_blob)`

## Complete Data Structures

### Chat (Composer) JSON

**Complete Structure** (Version 10):

```json
{
  "_v": 10,
  "composerId": "uuid",
  "name": "Chat title",
  "richText": "{\"root\":{\"children\":[{\"children\":[],\"format\":\"\",\"indent\":0,\"type\":\"paragraph\",\"version\":1}],\"format\":\"\",\"indent\":0,\"type\":\"root\",\"version\":1}}",
  "hasLoaded": true,
  "text": "",
  "createdAt": 1731348502000,
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

**Critical Composer Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `_v` | int | YES | Version number, must be 10 |
| `composerId` | string | YES | Chat UUID |
| `name` | string | YES | Chat title/name |
| `richText` | string | YES | Lexical editor JSON (as string) |
| `hasLoaded` | boolean | YES | Must be true for IDE to load |
| `text` | string | YES | Empty string "" |
| `createdAt` | int | YES | Unix timestamp (milliseconds) |
| `lastUpdatedAt` | int | YES | Unix timestamp (milliseconds) |
| `fullConversationHeadersOnly` | array | YES | List of {bubbleId, type} objects |

**Optional Composer Fields:**
- `isArchived`: boolean (default: false)
- `isDraft`: boolean (default: false)
- `totalLinesAdded`: int (default: 0)
- `totalLinesRemoved`: int (default: 0)
- `contextUsagePercent`: float (default: 0)

### Message (Bubble) JSON

**Complete Structure** (Version 3, 69+ fields):

```json
{
  "_v": 3,
  "type": 1,
  "bubbleId": "uuid",
  "text": "Message content",
  "createdAt": "2025-11-11T17:55:02.297Z",
  
  "requestId": "uuid",
  "checkpointId": "uuid",
  "richText": "{\"root\":{\"children\":[...]}}",
  
  "supportedTools": [1, 41, 7, 38, 8, 9, 11, 12, 15, 18, 19, 25, 27, 43, 46, 47, 29, 30, 32, 34, 35, 39, 40, 42, 44, 45],
  "tokenCount": {"inputTokens": 0, "outputTokens": 0},
  "context": {
    "composers": [], "quotes": [], "selectedCommits": [],
    "selectedPullRequests": [], "selectedImages": [], "folderSelections": [],
    "fileSelections": [], "terminalFiles": [], "selections": [],
    "terminalSelections": [], "selectedDocs": [], "externalLinks": [],
    "cursorRules": [], "cursorCommands": [], "uiElementSelections": [],
    "consoleLogs": [], "mentions": []
  },
  
  "isAgentic": true,
  "unifiedMode": 5,
  "toolFormerData": {},
  "thinking": {},
  
  "codeBlocks": [],
  "todos": [],
  
  "capabilityStatuses": {
    "mutate-request": [], "start-submit-chat": [], "before-submit-chat": [],
    "chat-stream-finished": [], "before-apply": [], "after-apply": [],
    "accept-all-edits": [], "composer-done": [], "process-stream": [],
    "add-pending-action": []
  },
  
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
  "uiElementPicked": [],
  "userResponsesToSuggestedCodeBlocks": [],
  
  "existedSubsequentTerminalCommand": false,
  "existedPreviousTerminalCommand": false,
  "editToolSupportsSearchAndReplace": true,
  "isNudge": false,
  "isPlanExecution": false,
  "isQuickSearchQuery": false,
  "isRefunded": false,
  "skipRendering": false,
  "useWeb": false,
  
  "modelInfo": {"modelName": "claude-4.5-sonnet"}
}
```

### Critical Bubble Fields

**Core Fields (Always Required):**

| Field | Type | Description |
|-------|------|-------------|
| `_v` | int | Version number, must be 3 |
| `type` | int | 1=user message, 2=assistant message |
| `bubbleId` | string | Unique message UUID |
| `text` | string | Message text content |
| `createdAt` | string | ISO 8601 timestamp with Z suffix |

**Request Tracking (Required):**

| Field | Type | Description |
|-------|------|-------------|
| `requestId` | string | UUID for request tracking |
| `checkpointId` | string | UUID for checkpoint tracking |

**Rich Content (Required):**

| Field | Type | Description |
|-------|------|-------------|
| `richText` | string | Lexical editor JSON (as string) |
| `supportedTools` | array | List of 26 tool IDs |
| `tokenCount` | object | {inputTokens: int, outputTokens: int} |
| `context` | object | 17 selection context keys (all arrays) |

**State Flags (Required):**

| Field | Type | Description |
|-------|------|-------------|
| `isAgentic` | boolean | true for user, false for assistant |
| `unifiedMode` | int | Standard value: 5 |
| `editToolSupportsSearchAndReplace` | boolean | true |

**Capability System (Required):**

| Field | Type | Description |
|-------|------|-------------|
| `capabilityStatuses` | object | 10 capability types, each with array |
| `toolFormerData` | object | Tool call data (can be empty) |
| `thinking` | object | Reasoning data (can be empty) |

**Content Arrays (21+ Required, Can Be Empty):**

All these fields must exist, even if empty `[]`:
- `approximateLintErrors`, `lints`, `codebaseContextChunks`
- `commits`, `pullRequests`, `attachedCodeChunks`
- `assistantSuggestedDiffs`, `gitDiffs`, `interpreterResults`
- `images`, `attachedFolders`, `attachedFoldersNew`
- `toolResults`, `notepads`, `capabilities`
- `multiFileLinterErrors`, `diffHistories`
- `recentLocationsHistory`, `recentlyViewedFiles`
- `fileDiffTrajectories`, `docsReferences`
- `webReferences`, `aiWebSearchResults`
- `attachedFoldersListDirResults`, `humanChanges`
- `allThinkingBlocks`, `attachedFileCodeChunksMetadataOnly`
- `capabilityContexts`, `consoleLogs`, `contextPieces`
- `cursorRules`, `deletedFiles`, `diffsForCompressingFiles`
- `diffsSinceLastApply`, `documentationSelections`
- `editTrailContexts`, `externalLinks`, `knowledgeItems`
- `projectLayouts`, `relevantFiles`, `suggestedCodeBlocks`
- `summarizedComposers`, `codeBlocks`, `todos`
- `uiElementPicked`, `userResponsesToSuggestedCodeBlocks`

**Boolean Flags (7 Required):**
- `existedSubsequentTerminalCommand`: false
- `existedPreviousTerminalCommand`: false
- `editToolSupportsSearchAndReplace`: true
- `isNudge`: false
- `isPlanExecution`: false
- `isQuickSearchQuery`: false
- `isRefunded`: false
- `skipRendering`: false
- `useWeb`: false

**Assistant-Only Fields:**

| Field | Type | Required For | Description |
|-------|------|--------------|-------------|
| `modelInfo` | object | type=2 only | {modelName: string} |

### Field Count Requirements

**Why 69+ Fields Matter:**

Cursor IDE validates the complete bubble structure when loading chats. Missing fields cause:
- Silent loading failures (no error logs)
- Chat won't appear in chat list
- Chat appears but won't open
- IDE hangs when trying to load

**Field Count by Source:**

| Source | Typical Field Count | IDE Compatible? |
|--------|---------------------|-----------------|
| Minimal API bubble | 21-30 fields | ❌ NO |
| Partial API bubble | 40-50 fields | ❌ NO |
| Complete Cursor bubble | 69+ fields | ✅ YES |

**Verification:**
```sql
-- Check field count in a bubble
SELECT 
  key,
  json_array_length(json_keys(value)) as field_count
FROM cursorDiskKV 
WHERE key LIKE 'bubbleId:%' 
LIMIT 1;
```

Should return 69 or more for IDE compatibility.

## Database Operations

### Read Operations

**Safe While Cursor Running:**
- SELECT queries
- Counting records
- Extracting schemas
- Analyzing structures

```bash
sqlite3 ~/Library/Application\ Support/Cursor/User/globalStorage/state.vscdb "
SELECT COUNT(*) FROM cursorDiskKV WHERE key LIKE 'composerData:%';
"
```

### Write Operations

**DANGER: Database Locking**

Writing while Cursor is running can cause:
- Database corruption
- Lost messages
- Cursor crash
- Data conflicts

**Safe Write Procedure:**
1. Close Cursor IDE completely
2. Backup database: `cp state.vscdb state.vscdb.backup`
3. Perform write operations
4. Verify writes: Check field counts and required fields
5. Reopen Cursor IDE

**Example Write:**
```python
import sqlite3
import json

conn = sqlite3.connect(db_path)
cursor = conn.cursor()

try:
    # Insert bubble
    cursor.execute(
        "INSERT INTO cursorDiskKV (key, value) VALUES (?, ?)",
        (f'bubbleId:{chat_id}:{bubble_id}', json.dumps(bubble_data))
    )
    conn.commit()
except Exception as e:
    conn.rollback()
    raise
finally:
    conn.close()
```

### Query Patterns

**List All Chats:**
```sql
SELECT key, value 
FROM cursorDiskKV 
WHERE key LIKE 'composerData:%'
ORDER BY json_extract(value, '$.lastUpdatedAt') DESC;
```

**Get Chat Metadata:**
```sql
SELECT value 
FROM cursorDiskKV 
WHERE key = 'composerData:YOUR_CHAT_ID';
```

**Get All Messages for Chat:**
```sql
SELECT key, value 
FROM cursorDiskKV 
WHERE key LIKE 'bubbleId:YOUR_CHAT_ID:%'
ORDER BY json_extract(value, '$.createdAt');
```

**Count Messages by Type:**
```sql
SELECT 
  json_extract(value, '$.type') as msg_type,
  COUNT(*) as count
FROM cursorDiskKV 
WHERE key LIKE 'bubbleId:YOUR_CHAT_ID:%'
GROUP BY msg_type;
```

**Find Incomplete Bubbles:**
```sql
SELECT 
  key,
  json_array_length(json_keys(value)) as field_count
FROM cursorDiskKV 
WHERE key LIKE 'bubbleId:%'
  AND json_array_length(json_keys(value)) < 69;
```

**Check for Missing composerData:**
```sql
-- Get bubbles without corresponding composer
SELECT DISTINCT 
  substr(key, 10, 36) as chat_id
FROM cursorDiskKV 
WHERE key LIKE 'bubbleId:%'
  AND 'composerData:' || substr(key, 10, 36) NOT IN (
    SELECT key FROM cursorDiskKV WHERE key LIKE 'composerData:%'
  );
```

## Best Practices for IDE Compatibility

### 8-Point Checklist

**Before Writing to Database:**

1. ✅ **Complete Structure**: Include all 69+ fields
2. ✅ **Proper Versions**: `_v: 3` for bubbles, `_v: 10` for composers
3. ✅ **Unique IDs**: Generate fresh UUIDs for requestId/checkpointId
4. ✅ **richText Format**: Valid Lexical editor JSON
5. ✅ **All Arrays Present**: Even if empty, all 21+ arrays must exist
6. ✅ **Boolean Flags**: All 7+ boolean flags with correct defaults
7. ✅ **Type-Specific Fields**: modelInfo for assistant (type=2) messages
8. ✅ **Composer Sync**: Update fullConversationHeadersOnly array

### Auto-Create Pattern

**Problem:** `cursor-agent create-chat` generates UUID but doesn't create database entry.

**Solution:** Auto-create composerData on first message if missing.

```python
def ensure_chat_exists(chat_id: str, cursor):
    """Create composerData entry if it doesn't exist."""
    cursor.execute(
        "SELECT value FROM cursorDiskKV WHERE key = ?",
        (f'composerData:{chat_id}',)
    )
    
    if not cursor.fetchone():
        # Create minimal composer metadata
        metadata = create_composer_metadata(chat_id)
        cursor.execute(
            "INSERT INTO cursorDiskKV (key, value) VALUES (?, ?)",
            (f'composerData:{chat_id}', json.dumps(metadata))
        )
        return True
    return False
```

**When to Use:**
- After calling `cursor-agent create-chat`
- Before sending first message to new chat
- In REST API endpoints that accept chat_id parameter
- After manual chat ID generation

### Updating Composer Metadata

**Always Update When Adding Messages:**

```python
def add_message_to_conversation(chat_id: str, bubble_id: str, msg_type: int):
    """Update composer's fullConversationHeadersOnly array."""
    cursor.execute(
        "SELECT value FROM cursorDiskKV WHERE key = ?",
        (f'composerData:{chat_id}',)
    )
    
    metadata = json.loads(cursor.fetchone()[0])
    
    # Add bubble reference
    metadata['fullConversationHeadersOnly'].append({
        "bubbleId": bubble_id,
        "type": msg_type
    })
    
    # Update timestamp
    metadata['lastUpdatedAt'] = int(time.time() * 1000)
    
    cursor.execute(
        "UPDATE cursorDiskKV SET value = ? WHERE key = ?",
        (json.dumps(metadata), f'composerData:{chat_id}')
    )
```

### richText Format

**Lexical Editor Structure:**

```json
{
  "root": {
    "children": [
      {
        "children": [
          {
            "detail": 0,
            "format": 0,
            "mode": "normal",
            "style": "",
            "text": "Your message text here",
            "type": "text",
            "version": 1
          }
        ],
        "direction": null,
        "format": "",
        "indent": 0,
        "type": "paragraph",
        "version": 1
      }
    ],
    "direction": null,
    "format": "",
    "indent": 0,
    "type": "root",
    "version": 1
  }
}
```

**Important:**
- richText is stored as **string** (JSON stringified)
- Empty composer richText must still have valid structure
- paragraph children array can be empty for composer

### supportedTools Array

**Standard 26 Tool IDs:**
```json
[1, 41, 7, 38, 8, 9, 11, 12, 15, 18, 19, 25, 27, 43, 46, 47, 29, 30, 32, 34, 35, 39, 40, 42, 44, 45]
```

Use this exact array for all bubbles unless you have specific tool requirements.

### context Object Structure

**All 17 Keys Required:**
```json
{
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
}
```

## Investigation Tools

**Location:** `/Users/davell/Documents/github/blink/rest/scripts/`

### extract_bubble_schema.py

Extract complete schemas from working Cursor chats.

```bash
cd /Users/davell/Documents/github/blink/rest/scripts
python3 extract_bubble_schema.py

# Outputs:
# - Complete bubble structure with all fields
# - Complete composer structure
# - Field counts and types
```

### compare_bubble_structures.py

Side-by-side comparison of API-created vs Cursor-created messages.

```bash
python3 compare_bubble_structures.py

# Shows:
# - Missing fields in API bubbles
# - Extra fields in Cursor bubbles
# - Field type mismatches
# - Compatibility issues
```

### repair_broken_chat.py

Fix chats with incomplete structures.

```bash
# List chats with issues
python3 repair_broken_chat.py --list

# Analyze specific chat
python3 repair_broken_chat.py YOUR_CHAT_ID

# Repair and apply fix
python3 repair_broken_chat.py YOUR_CHAT_ID --apply
```

**What it fixes:**
- Missing required fields
- Incorrect field types
- Empty arrays vs missing arrays
- Version numbers
- richText structure

### test_api_chat_creation.py

Integration test for complete workflow.

```bash
python3 test_api_chat_creation.py

# Tests:
# 1. Chat creation
# 2. Database entry creation
# 3. Message sending
# 4. Structure validation
# 5. IDE loading compatibility
```

## Common Issues and Solutions

### Chat Won't Load in Cursor IDE

**Symptoms:**
- Chat appears in list but won't open
- IDE hangs when clicking chat
- No error messages in console

**Cause:** Incomplete bubble structure (missing required fields)

**Diagnosis:**
```sql
-- Check field counts
SELECT 
  key,
  json_array_length(json_keys(value)) as field_count
FROM cursorDiskKV 
WHERE key LIKE 'bubbleId:YOUR_CHAT_ID:%';
```

**Solution:**
```bash
cd rest/scripts
python3 repair_broken_chat.py YOUR_CHAT_ID --apply
```

Or ensure your API includes all 69+ fields when creating bubbles.

### 404 Error on First Message

**Symptoms:**
- Called `cursor-agent create-chat`
- Got UUID back
- Sending message returns 404

**Cause:** `create-chat` only generates UUID, doesn't create database entry

**Solution:**
Implement auto-create pattern in your API:

```python
# In your send_message endpoint
cursor.execute("SELECT value FROM cursorDiskKV WHERE key = ?", 
               (f'composerData:{chat_id}',))
if not cursor.fetchone():
    # Create entry before proceeding
    metadata = create_composer_metadata(chat_id)
    cursor.execute("INSERT INTO cursorDiskKV (key, value) VALUES (?, ?)",
                   (f'composerData:{chat_id}', json.dumps(metadata)))
```

### Chat Works in API But Not in IDE

**Symptoms:**
- REST API returns chat correctly
- Mobile/Flutter app shows chat
- Cursor IDE won't load it

**Cause:** API/mobile apps work with minimal fields, IDE requires complete structure

**Solution:**
Validate field count before considering write successful:

```python
if len(bubble.keys()) < 69:
    raise ValueError(f"Incomplete bubble: only {len(bubble.keys())} fields")
```

### Database Locked Error

**Symptoms:**
```
sqlite3.OperationalError: database is locked
```

**Cause:** Cursor IDE is running and has write lock

**Solution:**
1. Close Cursor IDE completely
2. Wait 2-3 seconds for locks to release
3. Retry operation
4. Or use read-only mode: `sqlite3 file:state.vscdb?mode=ro`

### Type Errors from Malformed Arrays

**Symptoms:**
```
TypeError: string is not a subtype of Map<String, dynamic>
```

**Cause:** Array fields (todos, codeBlocks) contain strings instead of objects

**Solution:**
Filter arrays before sending to client:

```python
def clean_array_field(arr):
    """Remove non-dict items from arrays."""
    if not isinstance(arr, list):
        return []
    return [item for item in arr if isinstance(item, dict)]

# Apply to todos and codeBlocks
bubble['todos'] = clean_array_field(bubble.get('todos', []))
bubble['codeBlocks'] = clean_array_field(bubble.get('codeBlocks', []))
```

### Missing richText Field

**Symptoms:**
- Chat created successfully
- Won't load in IDE
- No errors in logs

**Cause:** richText field missing or not in Lexical format

**Solution:**
Always include richText with valid Lexical JSON:

```python
rich_text = {
    "root": {
        "children": [{
            "children": [{
                "text": text,
                "type": "text",
                "version": 1,
                # ... other required fields
            }],
            "type": "paragraph",
            "version": 1
        }],
        "type": "root",
        "version": 1
    }
}
bubble['richText'] = json.dumps(rich_text)
```

## Safety Considerations

### Read Operations

**Safe:**
- SELECT queries while Cursor running
- Analyzing schemas
- Counting records
- Extracting data for display

**Best Practice:**
```python
# Read-only connection
conn = sqlite3.connect(f'file:{db_path}?mode=ro', uri=True)
```

### Write Operations

**Unsafe (High Risk):**
- Writing while Cursor running
- Not backing up first
- Incomplete field structures
- Missing version numbers

**Safe Write Checklist:**
1. ✅ Cursor IDE closed
2. ✅ Database backed up
3. ✅ Structure validated (69+ fields)
4. ✅ Transaction used (commit/rollback)
5. ✅ Error handling implemented
6. ✅ Verification after write

### Backup Strategy

**Before Any Write:**
```bash
# Backup with timestamp
cp ~/Library/Application\ Support/Cursor/User/globalStorage/state.vscdb \
   ~/Library/Application\ Support/Cursor/User/globalStorage/state.vscdb.$(date +%Y%m%d_%H%M%S).backup
```

**Restore if Needed:**
```bash
# Replace with backup
cp state.vscdb.TIMESTAMP.backup state.vscdb
```

### Validation Before Write

```python
def validate_before_write(bubble: dict, composer: dict = None):
    """Validate structures before database write."""
    errors = []
    
    # Check bubble
    if bubble:
        if bubble.get('_v') != 3:
            errors.append("Bubble version must be 3")
        if len(bubble.keys()) < 69:
            errors.append(f"Bubble has only {len(bubble.keys())} fields, need 69+")
        if not bubble.get('richText'):
            errors.append("Missing richText field")
        if not bubble.get('supportedTools'):
            errors.append("Missing supportedTools field")
    
    # Check composer
    if composer:
        if composer.get('_v') != 10:
            errors.append("Composer version must be 10")
        if not composer.get('richText'):
            errors.append("Missing composer richText")
        if composer.get('hasLoaded') != True:
            errors.append("hasLoaded must be true")
    
    if errors:
        raise ValueError(f"Validation failed: {', '.join(errors)}")
```

## Via REST API

If using the Blink REST API (`/Users/davell/Documents/github/blink/rest/cursor_chat_api.py`):

```bash
# Start API server
cd rest
./start_api.sh

# Access at http://localhost:8000
# Docs at http://localhost:8000/docs
```

**API automatically handles:**
- Complete 69+ field bubble creation
- Auto-create composerData if missing
- richText generation
- Field validation
- Array cleaning (removes string items)

**Key Endpoints:**
- `GET /chats` - List all chats
- `GET /chat/{chat_id}` - Get chat metadata
- `GET /chat/{chat_id}/messages` - Get all messages
- `POST /agent/send-prompt` - Send message (auto-creates missing composers)

## Diagnostic Commands

**Check Database Health:**
```bash
# Table integrity
sqlite3 state.vscdb "PRAGMA integrity_check;"

# Database size
ls -lh state.vscdb

# Total chats
sqlite3 state.vscdb "SELECT COUNT(*) FROM cursorDiskKV WHERE key LIKE 'composerData:%';"

# Total messages
sqlite3 state.vscdb "SELECT COUNT(*) FROM cursorDiskKV WHERE key LIKE 'bubbleId:%';"
```

**Field Count Analysis:**
```bash
# Get field counts for all bubbles
sqlite3 state.vscdb "
SELECT 
  CASE 
    WHEN json_array_length(json_keys(value)) < 30 THEN 'Minimal (<30)'
    WHEN json_array_length(json_keys(value)) < 69 THEN 'Incomplete (30-68)'
    ELSE 'Complete (69+)'
  END as status,
  COUNT(*) as count
FROM cursorDiskKV 
WHERE key LIKE 'bubbleId:%'
GROUP BY status;
"
```

**Find Chats with Issues:**
```bash
# Chats with incomplete bubbles
sqlite3 state.vscdb "
SELECT DISTINCT substr(key, 10, 36) as chat_id
FROM cursorDiskKV 
WHERE key LIKE 'bubbleId:%'
  AND json_array_length(json_keys(value)) < 69;
"
```

**Compare Structures:**
```bash
cd rest/scripts

# Extract complete schema from working chat
python3 extract_bubble_schema.py > cursor_schema.json

# Compare API vs Cursor
python3 compare_bubble_structures.py
```

## Related Skills

- **cursor-internals** - For authentication, API, and cursor-agent CLI
- **blink-api-dev** - For REST API endpoint development
- **blink-debugging** - For troubleshooting full-stack issues

## Code Examples

See [EXAMPLES.md](EXAMPLES.md) for complete working code examples including:
- Creating complete 69+ field bubbles
- Writing to database safely
- Validating structures
- Repairing broken chats
- Complete workflow implementations

