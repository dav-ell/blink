# Cursor Internals Skill

## Purpose
Specialized knowledge of Cursor IDE's internal architecture, authentication system, API structure, and database schema discovered through reverse engineering.

## When to Use
- Integrating with Cursor's backend API
- Understanding Cursor's authentication flow
- Working with Cursor's local database directly
- Discovering and testing API endpoints
- Troubleshooting authentication issues
- Finding protobuf message definitions
- Building tools that interact with Cursor's services

## Quick Start

### Authentication Overview
Cursor uses **Auth0 OAuth** for authentication with JWT bearer tokens.

**Key URLs**:
- Auth: `https://authentication.cursor.sh`
- API: `https://api2.cursor.sh`
- Telemetry: `https://api3.cursor.sh`

**Required Headers**:
```http
Authorization: Bearer <jwt_token>
Content-Type: application/json
X-Cursor-User-Id: auth0|user_<identifier>
X-Cursor-Client-Version: 2.0.69
```

### Capturing Your Token
Tokens are stored in-memory only, not on disk. Capture via HTTPS interception:

```bash
cd ~/Documents/github/blink/tools
./capture_cursor_auth.sh
```

Tool will guide you through:
1. Installing mitmproxy
2. Installing SSL certificate
3. Proxying Cursor traffic
4. Extracting token from logs

Token location after capture: `tools/.cursor_token` (git-ignored)

## Architecture Deep Dive

### Dual Protocol System

Cursor's API uses **two different protocols** depending on endpoint complexity:

#### 1. JSON Endpoints (Simple Queries)
Work with plain HTTP/JSON - accessible via curl/requests.

**Working Endpoints**:
- `/aiserver.v1.AiService/AvailableModels` - List 40+ AI models
- `/aiserver.v1.AiService/GetDefaultModel` - Get default model
- `/aiserver.v1.AiService/CheckFeaturesStatus` - Feature flags
- `/aiserver.v1.AiService/KnowledgeBaseList` - Knowledge bases
- `/aiserver.v1.AiService/CheckNumberConfig` - Usage quotas
- `/aiserver.v1.AiService/AvailableDocs` - Documentation sources

**Characteristics**:
- Accept: `application/json`
- Simple request/response
- POST method with empty body `{}`
- No streaming

#### 2. Protobuf Endpoints (Complex Operations)
Require Protocol Buffers encoding via gRPC.

**Endpoints** (Not accessible via plain JSON):
- `/aiserver.v1.AiService/GetCompletionStream` - Chat/completions
- `/aiserver.v1.ToolCallEventService/SubmitToolCallEvents` - Tool calls
- `/aiserver.v1.AnalyticsService/Batch` - Analytics
- `/aiserver.v1.AiService/CheckQueuePosition` - Queue status

**Characteristics**:
- Content-Type: `application/proto`
- Binary protobuf encoding
- Streaming support (SSE)
- Connect-RPC protocol
- User-Agent: `connect-es/1.6.1`

### Network Stack

```
Cursor IDE (Electron)
    ↓
connect-es (gRPC-Web Client)
    ↓ 
HTTP/2 + Protocol Buffers
    ↓
api2.cursor.sh (AWS us-east-1)
    ↓
AI Providers (Anthropic, OpenAI, etc.)
```

## Database Structure

### Location
```
macOS: ~/Library/Application Support/Cursor/User/globalStorage/state.vscdb
```

### Schema

**Tables**:
- `cursorDiskKV` - Key-value store (main data)
- `ItemTable` - Active panel state

**Key Patterns in cursorDiskKV**:
```sql
composerData:{uuid}        -- Chat metadata
bubbleId:{composer}:{uuid} -- Individual messages
```

### Data Structures

**Chat (Composer) JSON** - Complete Structure:
```json
{
  "_v": 10,
  "composerId": "uuid",
  "name": "Chat title",
  "richText": "{\"root\":{\"children\":[...]}}",
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

**Critical Composer Fields** (required for Cursor IDE):
- `_v`: 10 (version number)
- `richText`: Lexical editor state JSON
- `hasLoaded`: true
- `text`: "" (empty string)

**Message (Bubble) JSON** - Complete Structure (69+ fields):
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
  "approximateLintErrors": [], "lints": [], "codebaseContextChunks": [],
  "commits": [], "pullRequests": [], "attachedCodeChunks": [],
  "assistantSuggestedDiffs": [], "gitDiffs": [], "interpreterResults": [],
  "images": [], "attachedFolders": [], "attachedFoldersNew": [],
  "toolResults": [], "notepads": [], "capabilities": [],
  "multiFileLinterErrors": [], "diffHistories": [],
  "recentLocationsHistory": [], "recentlyViewedFiles": [],
  "fileDiffTrajectories": [], "docsReferences": [],
  "webReferences": [], "aiWebSearchResults": [],
  "attachedFoldersListDirResults": [], "humanChanges": [],
  "allThinkingBlocks": [], "attachedFileCodeChunksMetadataOnly": [],
  "capabilityContexts": [], "consoleLogs": [], "contextPieces": [],
  "cursorRules": [], "deletedFiles": [], "diffsForCompressingFiles": [],
  "diffsSinceLastApply": [], "documentationSelections": [],
  "editTrailContexts": [], "externalLinks": [], "knowledgeItems": [],
  "projectLayouts": [], "relevantFiles": [], "suggestedCodeBlocks": [],
  "summarizedComposers": [], "uiElementPicked": [],
  "userResponsesToSuggestedCodeBlocks": [],
  "existedSubsequentTerminalCommand": false,
  "existedPreviousTerminalCommand": false,
  "editToolSupportsSearchAndReplace": true,
  "isNudge": false, "isPlanExecution": false,
  "isQuickSearchQuery": false, "isRefunded": false,
  "skipRendering": false, "useWeb": false
}
```

**Critical Bubble Fields** (required for Cursor IDE to load):
- `_v`: 3 (bubble version)
- `requestId`: UUID for request tracking
- `checkpointId`: UUID for checkpoint
- `richText`: Lexical editor JSON format
- `supportedTools`: Array of 26 tool IDs
- `tokenCount`: Object with inputTokens/outputTokens
- `context`: Object with 17 selection context keys
- `isAgentic`: true for user, false for assistant
- `unifiedMode`: 5 (standard value)
- `capabilityStatuses`: Dict with 10 capability types
- All 21+ array fields (can be empty)
- All 7 boolean flags
- `modelInfo`: {"modelName": "..."} (assistant only)

**Type Values**:
- `1` = User message
- `2` = Assistant message

**Field Count**:
- Minimal API bubble: 21 fields
- Complete Cursor bubble: 69+ fields
- Missing fields cause IDE loading failures

### Querying the Database

**Direct SQLite**:
```bash
sqlite3 ~/Library/Application\ Support/Cursor/User/globalStorage/state.vscdb

-- List all chats
SELECT key, value FROM cursorDiskKV WHERE key LIKE 'composerData:%';

-- Get messages for specific chat
SELECT key, value FROM cursorDiskKV WHERE key LIKE 'bubbleId:<chat_id>:%';
```

**Via REST API**:
```bash
cd ~/Documents/github/blink/rest
python3 cursor_chat_api.py
# Access at http://localhost:8000
```

## Machine Identifiers

Cursor tracks three machine identifiers:

**Storage location**: `~/Library/Application Support/Cursor/User/storage.json`

**IDs**:
- `telemetry.machineId` - Machine identifier
- `telemetry.devDeviceId` - Device UUID
- `telemetry.macMachineId` - Mac-specific ID

**Extraction script**:
```bash
cd ~/Documents/github/blink/tools
python3 extract_cursor_auth.py
```

Output: `cursor_auth_data.json` with all IDs

## Authentication System

### Token Structure

**Format**: JWT (JSON Web Token)
**Algorithm**: HS256

**Payload**:
```json
{
  "sub": "auth0|user_<identifier>",
  "time": "timestamp",
  "randomness": "uuid",
  "exp": 1767531038,
  "iss": "https://authentication.cursor.sh",
  "scope": "openid profile email offline_access",
  "aud": "https://cursor.com",
  "type": "session"
}
```

**Expiration**: Typically 53-60 days

### Token Capture Process

1. **Install mitmproxy**: `brew install mitmproxy`
2. **Generate certificate**: Run mitmproxy once
3. **Install cert**: Add to macOS System Keychain
4. **Proxy Cursor**: Set `HTTP_PROXY` and `HTTPS_PROXY`
5. **Use Cursor**: Chat feature generates API calls
6. **Extract token**: From Authorization header in logs

**Automated script**: `tools/capture_cursor_auth.sh`

### Token Storage

**Local storage**:
- NOT in plain text files
- NOT in database
- NOT in keychain
- Only in memory during runtime

**After capture**:
- Stored in `tools/.cursor_token` (git-ignored)
- Use environment variables:
  ```bash
  export CURSOR_AUTH_TOKEN="$(cat tools/.cursor_token)"
  export CURSOR_USER_ID="auth0|user_<your_id>"
  ```

## Working with the API

### Python Example

```python
import requests
import os

class CursorAPI:
    def __init__(self):
        self.base_url = "https://api2.cursor.sh"
        self.token = os.getenv('CURSOR_AUTH_TOKEN')
        self.user_id = os.getenv('CURSOR_USER_ID')
        
    def _headers(self):
        return {
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json",
            "X-Cursor-User-Id": self.user_id,
            "X-Cursor-Client-Version": "2.0.69"
        }
    
    def list_models(self):
        """Get all available AI models"""
        response = requests.post(
            f"{self.base_url}/aiserver.v1.AiService/AvailableModels",
            headers=self._headers(),
            json={}
        )
        return response.json()
    
    def check_features(self):
        """Check enabled features"""
        response = requests.post(
            f"{self.base_url}/aiserver.v1.AiService/CheckFeaturesStatus",
            headers=self._headers(),
            json={}
        )
        return response.json()
    
    def get_quotas(self):
        """Check usage quotas"""
        response = requests.post(
            f"{self.base_url}/aiserver.v1.AiService/CheckNumberConfig",
            headers=self._headers(),
            json={}
        )
        return response.json()

# Usage
api = CursorAPI()
models = api.list_models()
print(f"Found {len(models['models'])} models")
```

### Dart/Flutter Example

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class CursorAPIClient {
  final String baseUrl = 'https://api2.cursor.sh';
  final String authToken;
  final String userId;

  CursorAPIClient({
    required this.authToken,
    required this.userId,
  });

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $authToken',
    'Content-Type': 'application/json',
    'X-Cursor-User-Id': userId,
    'X-Cursor-Client-Version': '2.0.69',
  };

  Future<Map<String, dynamic>> listModels() async {
    final response = await http.post(
      Uri.parse('$baseUrl/aiserver.v1.AiService/AvailableModels'),
      headers: _headers,
      body: jsonEncode({}),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load models: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> checkFeatures() async {
    final response = await http.post(
      Uri.parse('$baseUrl/aiserver.v1.AiService/CheckFeaturesStatus'),
      headers: _headers,
      body: jsonEncode({}),
    );
    return jsonDecode(response.body);
  }
}

// Usage
final api = CursorAPIClient(
  authToken: yourToken,
  userId: yourUserId,
);

final models = await api.listModels();
print('Found ${models['models'].length} models');
```

## Available AI Models

Cursor provides access to 40+ AI models:

**Cursor's Own**:
- `composer-1` - Cursor's agentic coding model (200k context)
- `default` - General model

**Claude (Anthropic)** - 8+ variants:
- `claude-4.5-sonnet` - Latest model (200k context)
- `claude-4.5-sonnet-thinking` - With reasoning
- `claude-4.5-haiku` - Fast and cheap
- `claude-4.1-opus` - Most powerful
- Plus thinking and legacy variants

**GPT-5 (OpenAI)** - 15+ variants:
- `gpt-5` - Latest flagship
- `gpt-5-codex` - Coding specialist
- `gpt-5-codex-high` - High reasoning
- `gpt-5-fast` - Priority processing (2x cost)
- Multiple reasoning levels (low/medium/high)

**Reasoning Models**:
- `o3` - Deep reasoning
- `o3-pro` - Most complex reasoning

**Google**:
- `gemini-2.5-pro` - 1M context
- `gemini-2.5-flash` - Fast variant

**Others**:
- `grok-4` (xAI)
- `grok-code-fast-1` - Free during promo
- `deepseek-r1`, `deepseek-v3.1`
- `kimi-k2-instruct`

## Protobuf Discovery

To enable chat functionality, you need protobuf definitions.

### Method 1: Extract from Electron App

```bash
# Find .proto references
strings /Applications/Cursor.app/Contents/MacOS/Cursor | grep "\.proto"

# Search for service names
strings /Applications/Cursor.app/Contents/MacOS/Cursor | grep -i "aiservice\|GetCompletionStream"

# Extract asar archive
npm install -g asar
asar extract /Applications/Cursor.app/Contents/Resources/app.asar /tmp/cursor_extracted

# Search extracted files
cd /tmp/cursor_extracted
grep -r "GetCompletionStream" . --include="*.js"
grep -r "message.*Request\|message.*Response" . --include="*.js"
```

### Method 2: Analyze Binary Traffic

```bash
cd ~/Documents/github/blink/tools/auth_captures

# Find protobuf requests
grep -B 5 -A 30 "application/proto" cursor_auth_*.log

# Decode binary payloads
echo "<hex_payload>" | xxd -r -p | protoc --decode_raw
```

### Method 3: gRPC Reflection

```bash
# Try to list services
grpcurl -H "Authorization: Bearer $CURSOR_AUTH_TOKEN" \
  api2.cursor.sh:443 list

# If it works, describe the service
grpcurl -H "Authorization: Bearer $CURSOR_AUTH_TOKEN" \
  api2.cursor.sh:443 describe aiserver.v1.AiService
```

### What You're Looking For

Expected protobuf structure:

```protobuf
syntax = "proto3";

package aiserver.v1;

service AiService {
  rpc GetCompletionStream(CompletionRequest) returns (stream CompletionResponse);
}

message CompletionRequest {
  string prompt = 1;
  int32 max_tokens = 2;
  string model = 3;
  repeated Message messages = 4;
}

message CompletionResponse {
  string content = 1;
  bool done = 2;
}
```

## Troubleshooting

### Common Issues

**Chat Created but 404 on First Message**:
- `cursor-agent create-chat` only generates UUID, doesn't create database entry
- Entry is created when first message is sent
- Solution: Auto-create composerData entry if missing when sending message
- Check: `SELECT * FROM cursorDiskKV WHERE key = 'composerData:{chat_id}'`

**Chat Won't Load in Cursor IDE**:
- Bubble structure is incomplete (missing required fields)
- Need all 69+ fields for IDE compatibility
- Common missing fields: `supportedTools`, `tokenCount`, `context`, `richText`
- Solution: Use complete bubble structure or repair with `repair_broken_chat.py`
- Verify: Check field count in database, should be 69+ not 20-30

**Chat Works in API/App but Not in IDE**:
- API/mobile apps often work with minimal fields
- Cursor IDE requires complete structure for loading
- Missing fields cause silent failures (no error logs)
- Fix: Ensure all 69+ fields are present in bubbles

**404 on Chat Endpoints**:
- Chat doesn't exist in database (composerData entry missing)
- Or endpoint exists but requires protobuf encoding
- JSON payloads may be rejected for protobuf endpoints
- Check database first: `composerData:{chat_id}` should exist

**Token Expired**:
- Check expiration in decoded JWT
- Re-run capture process
- Tokens typically last 53-60 days

**Database Locked**:
- Cursor is writing to database
- Close Cursor for write operations
- Read operations are safe while Cursor is open

**SSL Certificate Errors**:
- mitmproxy cert not trusted
- Install to System Keychain
- Run: `tools/capture_cursor_auth.sh` (option 1)

**Connection Refused**:
- Check API is reachable: `curl https://api2.cursor.sh`
- Verify token in Authorization header
- Check User ID format: `auth0|user_*`

### Diagnostic Commands

```bash
# Test authentication
curl -X POST https://api2.cursor.sh/aiserver.v1.AiService/AvailableModels \
  -H "Authorization: Bearer $CURSOR_AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -H "X-Cursor-User-Id: $CURSOR_USER_ID" \
  -H "X-Cursor-Client-Version: 2.0.69" \
  -d '{}'

# Check database
sqlite3 ~/Library/Application\ Support/Cursor/User/globalStorage/state.vscdb ".tables"

# Check if chat exists
sqlite3 ~/Library/Application\ Support/Cursor/User/globalStorage/state.vscdb \
  "SELECT key FROM cursorDiskKV WHERE key = 'composerData:YOUR_CHAT_ID'"

# Count fields in a bubble (should be 69+)
sqlite3 ~/Library/Application\ Support/Cursor/User/globalStorage/state.vscdb \
  "SELECT json_array_length(json_keys(value)) FROM cursorDiskKV WHERE key LIKE 'bubbleId:YOUR_CHAT_ID:%' LIMIT 1"

# Monitor network
cd ~/Documents/github/blink/tools
./monitor_cursor_traffic.sh

# Extract credentials
python3 extract_cursor_auth.py

# Extract and compare bubble structures
cd ~/Documents/github/blink/rest/scripts
python3 extract_bubble_schema.py
python3 compare_bubble_structures.py

# Test API chat creation
python3 test_api_chat_creation.py

# Repair broken chat
python3 repair_broken_chat.py --list
python3 repair_broken_chat.py YOUR_CHAT_ID
```

## Security Considerations

### Token Safety

**Do**:
- Store tokens in environment variables
- Use git-ignored files (`.cursor_token`)
- Rotate tokens when expired
- Use HTTPS only

**Don't**:
- Commit tokens to git
- Share tokens publicly
- Hardcode in source code
- Use tokens in client-side JavaScript

### Database Safety

**Read Operations**:
- Safe while Cursor is running
- Use SELECT queries only
- No risk of corruption

**Write Operations**:
- Close Cursor first to avoid conflicts
- Risk of database corruption if Cursor is running
- Must use complete field structure for IDE compatibility
- Incomplete bubbles (missing fields) will break IDE loading
- Always validate bubble structure has all 69+ required fields

### Privacy Mode

If Cursor is in privacy mode:
- `privacyModeType`: `"NO_TRAINING"`
- Data not used for training
- Check in `storage.json`

## Reference Documentation

### In This Repository

- `WORKING_API_REFERENCE.md` - JSON endpoints with examples
- `CHAT_API_ANALYSIS.md` - Protobuf architecture details
- `SUCCESS_REPORT.md` - Investigation summary
- `CURSOR_AUTH_GUIDE.md` - Complete authentication guide
- `DISCOVERED_API_ENDPOINTS.md` - Full endpoint catalog
- `YOUR_CURSOR_TOKEN.md` - Token usage guide

### Tools

- `tools/capture_cursor_auth.sh` - Interactive token capture
- `tools/extract_cursor_auth.py` - Extract IDs from local files
- `tools/extract_cursor_api_info.py` - Analyze database
- `tools/monitor_cursor_traffic.sh` - Network monitoring
- `tools/test_token.sh` - Validate token

### Code Examples

- `examples/cursor_api_python_example.py` - Python SDK
- `lib/services/cursor_api_service.dart` - Flutter SDK

## Cursor-Agent CLI Deep Dive

### Understanding cursor-agent Behavior

**Installation:**
```bash
curl https://cursor.com/install -fsS | bash
```

**Command Types:**

1. **create-chat** - Generates chat ID only
```bash
cursor-agent create-chat
# Returns: uuid (e.g., 3f1a6a8c-58d1-4fbe-81f7-1ad946d9c84e)
# NOTE: Does NOT create database entry - entry created on first message
```

2. **Sending Messages** - Uses --resume flag
```bash
cursor-agent --print --force --resume <chat_id> "Your prompt"
# Automatically includes ALL chat history
# Writes both user and assistant messages to database
# Creates composerData entry if it doesn't exist
```

### Critical Discovery: Database Entry Creation

**Important:** `cursor-agent create-chat` ONLY generates a UUID. The actual database entry is created when:
1. First message is sent via cursor-agent
2. OR manually created via direct database write

**Implication for REST APIs:**
- After calling `/agent/create-chat`, the chat doesn't exist in database yet
- Sending a message to a "created" chat will fail with 404
- Solution: Auto-create composerData entry on first message if missing

### Complete Bubble Structure Requirements

**Why 69+ fields matter:**
- Cursor IDE validates bubble structure on load
- Missing critical fields cause silent loading failures
- Chat won't appear or won't open in IDE
- iOS/Flutter apps may work with fewer fields (uses API directly)

**Must-have fields for IDE compatibility:**
```python
# Critical complex fields
"supportedTools": [1, 41, 7, 38, 8, 9, 11, 12, 15, 18, 19, 25, 27, 43, 46, 47, 29, 30, 32, 34, 35, 39, 40, 42, 44, 45]
"tokenCount": {"inputTokens": 0, "outputTokens": 0}
"context": {17 keys with empty arrays}
"richText": "{Lexical editor JSON}"
"requestId": "uuid"
"checkpointId": "uuid"
"capabilityStatuses": {10 capability types}

# Boolean flags
"isAgentic": true/false
"unifiedMode": 5
"editToolSupportsSearchAndReplace": true
# + 7 more boolean flags

# All array fields (21+)
"allThinkingBlocks": []
"supportedTools": [...]
# + 19 more arrays
```

### Investigation Tools

**Location:** `rest/scripts/`

1. **extract_bubble_schema.py** - Extract complete schemas from database
2. **compare_bubble_structures.py** - Compare API vs Cursor structures  
3. **repair_broken_chat.py** - Fix chats with incomplete structures
4. **test_api_chat_creation.py** - Test complete workflow

**Usage:**
```bash
cd rest/scripts

# Extract current schemas
python3 extract_bubble_schema.py

# Compare structures
python3 compare_bubble_structures.py

# Repair broken chat
python3 repair_broken_chat.py --list
python3 repair_broken_chat.py <chat_id> --apply
```

## Quick Reference

### Environment Setup

```bash
# Set credentials
export CURSOR_AUTH_TOKEN="<your_token>"
export CURSOR_USER_ID="auth0|user_<your_id>"

# Or load from file
export CURSOR_AUTH_TOKEN="$(cat tools/.cursor_token)"
```

### API Call Template

```bash
curl -X POST https://api2.cursor.sh/aiserver.v1.AiService/<EndpointName> \
  -H "Authorization: Bearer $CURSOR_AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -H "X-Cursor-User-Id: $CURSOR_USER_ID" \
  -H "X-Cursor-Client-Version: 2.0.69" \
  -d '{}'
```

### Database Write Best Practices

**For Cursor IDE Compatibility:**
1. Always use complete 69+ field bubble structure
2. Include all required arrays (even if empty)
3. Set proper `_v` versions (bubble: 3, composer: 10)
4. Generate unique `requestId` and `checkpointId`
5. Include `richText` in Lexical editor format
6. Set `isAgentic` based on message type
7. Include `supportedTools` array with standard 26 tools
8. Add `modelInfo` for assistant messages

**Auto-create Pattern:**
```python
# Check if chat exists
cursor.execute("SELECT value FROM cursorDiskKV WHERE key = ?", (f'composerData:{chat_id}',))
if not cursor.fetchone():
    # Create minimal composerData with all required fields
    # Then proceed with message creation
```

### Status Codes

- `200` - Success
- `401` - Unauthorized (bad token)
- `403` - Forbidden (expired token)
- `404` - Not found (or protobuf required, or chat doesn't exist)
- `429` - Rate limited
- `503` - Service unavailable

## Progressive Disclosure

### Basic (Start Here)
- Cursor uses OAuth/Auth0 authentication
- Two API types: JSON (simple) and Protobuf (chat)
- Token capture via mitmproxy
- 40+ AI models available

### Intermediate
- Connect-RPC protocol for protobuf
- SQLite database structure
- Machine identifiers
- Working code examples

### Advanced
- Protobuf definition discovery
- gRPC reflection attempts
- Binary traffic decoding
- Custom gRPC client implementation

## External Resources

- **Connect-RPC**: https://connectrpc.com/
- **Protocol Buffers**: https://protobuf.dev/
- **gRPC**: https://grpc.io/
- **mitmproxy**: https://mitmproxy.org/
- **Auth0**: https://auth0.com/docs

