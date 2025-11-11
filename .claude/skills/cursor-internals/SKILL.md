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

**Chat (Composer) JSON**:
```json
{
  "composerId": "uuid",
  "name": "Chat title",
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

**Message (Bubble) JSON**:
```json
{
  "_v": 10,
  "type": 1,
  "bubbleId": "uuid",
  "text": "Message content",
  "createdAt": "2025-11-11T17:55:02.297Z",
  "toolFormerData": {},
  "thinking": {},
  "codeBlocks": [],
  "todos": []
}
```

**Type Values**:
- `1` = User message
- `2` = Assistant message

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

**404 on Chat Endpoints**:
- Endpoint exists but requires protobuf encoding
- JSON payloads are rejected
- Need gRPC client with protobuf definitions

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

# Monitor network
cd ~/Documents/github/blink/tools
./monitor_cursor_traffic.sh

# Extract credentials
python3 extract_cursor_auth.py
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
- Close Cursor first
- Risk of database corruption
- Not recommended

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

### Status Codes

- `200` - Success
- `401` - Unauthorized (bad token)
- `403` - Forbidden (expired token)
- `404` - Not found (or protobuf required)
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

