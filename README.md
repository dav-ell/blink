# Blink - Mobile Chat Interface for Cursor IDE

A Flutter mobile app that lets you view and continue your Cursor IDE chat conversations from iOS/Android devices with full conversation context.

## Overview

Blink provides a mobile interface to your Cursor IDE chats, allowing you to:
- Browse all your Cursor chat sessions
- View full conversation history
- Continue conversations with automatic context preservation
- Use multiple AI models (GPT-5, Claude, Gemini, etc.)
- Track async job processing in real-time

## Architecture

Blink uses a three-layer architecture:

```
┌─────────────────────────────────────┐
│   Flutter App (iOS/Android)         │
│   - Chat list & detail screens      │
│   - Async job polling                │
│   - Real-time status updates         │
└──────────────┬──────────────────────┘
               │ HTTP REST API
┌──────────────▼──────────────────────┐
│   Python FastAPI Backend             │
│   - Reads Cursor's SQLite database   │
│   - Manages async job queue          │
│   - Calls cursor-agent CLI           │
└──────────────┬──────────────────────┘
               │ CLI Execution
┌──────────────▼──────────────────────┐
│   cursor-agent (Official CLI)        │
│   - Handles AI model routing         │
│   - Auto-includes conversation via   │
│     --resume flag                    │
└─────────────────────────────────────┘
```

### Frontend (Flutter)

**Location:** `lib/`

**Key Components:**
- `screens/chat_list_screen.dart` - Browse all chats
- `screens/chat_detail_screen.dart` - View messages and send prompts
- `services/cursor_agent_service.dart` - REST API client
- `services/job_polling_service.dart` - Async job status tracking
- `models/` - Message, Chat, Job data models
- `widgets/` - Reusable UI components (message bubbles, processing indicators)

**State Management:** Provider pattern for theme and chat state

### Backend (Python FastAPI)

**Location:** `rest/cursor_chat_api.py`

**Capabilities:**
- Direct SQLite access to Cursor's database (`~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`)
- Async job queue for non-blocking cursor-agent calls
- Full CRUD operations on chat messages
- Job status tracking and polling endpoints

**Key Features:**
- In-memory job storage with automatic cleanup (1 hour retention)
- Database transaction management for atomic message writes
- Concurrent cursor-agent execution support

### Cursor Agent

**Official Cursor CLI tool** - Installed separately

**Key Capability:** The `--resume <chat_id>` flag automatically includes all previous conversation history, eliminating the need for manual history formatting in the backend.

## Features

- ✅ **View All Chats** - Browse your Cursor conversations with metadata
- ✅ **Full History** - See complete conversation timeline
- ✅ **Continue Conversations** - Send new messages with automatic context
- ✅ **Async Processing** - Submit prompts and poll for results (non-blocking)
- ✅ **Multiple AI Models** - GPT-5, Claude Sonnet 4.5, Opus 4.1, Gemini, and more
- ✅ **Rich Content Display** - Tool calls, code blocks, thinking blocks, todos
- ✅ **Real-time Status** - Live updates on message processing status
- ✅ **Batch Operations** - Fetch multiple chat summaries at once

## Setup

### Prerequisites

- Python 3.8+ (backend)
- Flutter 3.0+ (frontend)
- Cursor IDE installed (for database access)
- cursor-agent CLI

### Backend Setup

1. **Install cursor-agent** (if not already installed):
```bash
curl https://cursor.com/install -fsS | bash
```

2. **Install Python dependencies**:
```bash
cd rest
pip install -r requirements_api.txt
```

3. **Start the API server**:
```bash
./start_api.sh
```

The server will start on `http://localhost:8000` with API documentation at `http://localhost:8000/docs`

### Frontend Setup

1. **Install Flutter dependencies**:
```bash
flutter pub get
```

2. **Configure API endpoint**:

Edit `lib/services/cursor_agent_service.dart` and update the `baseUrl`:
```dart
// For iOS Simulator
final String baseUrl = 'http://127.0.0.1:8000';

// For physical iOS device (use your Mac's IP)
final String baseUrl = 'http://192.168.1.120:8000';
```

3. **Run the app**:
```bash
# iOS Simulator
flutter run -d iPhone

# Physical device
flutter run
```

## How It Works

### Conversation Flow

When you continue a conversation in Blink:

1. **Frontend** - User selects a chat and types a message
2. **API Call** - App calls `POST /chats/{chat_id}/agent-prompt-async`
3. **Job Creation** - Backend creates an async job and returns `job_id`
4. **User Message** - Backend writes user message to Cursor database
5. **Cursor Agent** - Backend executes `cursor-agent --resume {chat_id} "prompt"`
6. **Auto History** - cursor-agent automatically loads conversation history
7. **AI Response** - Backend writes AI response to database
8. **Polling** - App polls `GET /jobs/{job_id}` for status updates
9. **Completion** - When status is "completed", app displays the response

### Key Insight: The `--resume` Flag

The cursor-agent's `--resume` flag handles all history automatically. The backend simply provides the chat ID, and cursor-agent loads all previous messages as context. This eliminates complex history management code.

### Async Job System

Blink uses an async job pattern for better UX:

- **Submit** - Prompt submitted, job ID returned immediately
- **Pending** - Job queued for processing
- **Processing** - cursor-agent running
- **Completed** - Response ready
- **Failed** - Error occurred (with details)

The frontend polls every 2 seconds during processing, showing elapsed time and status.

## API Endpoints

### Chat Operations
- `GET /chats` - List all chats with metadata
- `GET /chats/{id}` - Get full chat with all messages
- `GET /chats/{id}/summary` - Get chat preview with recent messages
- `GET /chats/{id}/metadata` - Get chat metadata only
- `POST /chats/batch-info` - Get info for multiple chats at once

### Conversation
- `POST /chats/{id}/agent-prompt-async` - Submit prompt (async, returns job_id)
- `POST /chats/{id}/agent-prompt` - Submit prompt (sync, blocks until complete)
- `POST /agent/create-chat` - Create new chat conversation

### Job Management
- `GET /jobs/{job_id}` - Get full job details
- `GET /jobs/{job_id}/status` - Quick status check
- `GET /chats/{id}/jobs` - List all jobs for a chat
- `DELETE /jobs/{job_id}` - Cancel pending/processing job

### System
- `GET /health` - Health check with database stats
- `GET /agent/models` - List available AI models

**Full API Documentation:** `http://localhost:8000/docs` (interactive Swagger UI)

## Project Structure

```
blink/
├── lib/                          # Flutter frontend
│   ├── main.dart                # App entry point
│   ├── models/                  # Data models
│   │   ├── chat.dart           # Chat metadata
│   │   ├── message.dart        # Message with status
│   │   ├── job.dart            # Async job tracking
│   │   ├── code_block.dart     # Code display
│   │   ├── tool_call.dart      # Tool call data
│   │   └── todo_item.dart      # Todo items
│   ├── screens/                 # UI screens
│   │   ├── chat_list_screen.dart    # Browse chats
│   │   └── chat_detail_screen.dart  # Chat view
│   ├── services/                # Business logic
│   │   ├── cursor_agent_service.dart    # API client
│   │   ├── job_polling_service.dart     # Job status polling
│   │   └── api_service.dart             # Low-level HTTP
│   ├── widgets/                 # Reusable components
│   │   ├── message_bubble.dart          # Message display
│   │   ├── processing_indicator.dart    # Status animation
│   │   └── ...
│   ├── providers/               # State management
│   │   └── theme_provider.dart
│   └── utils/
│       └── theme.dart          # App theming
│
├── rest/                        # Python backend
│   ├── cursor_chat_api.py      # FastAPI server (main)
│   ├── requirements_api.txt    # Python dependencies
│   ├── start_api.sh           # Server startup script
│   ├── conftest.py            # Test configuration
│   ├── test_*.py              # Test suites
│   └── README.md              # Backend documentation
│
├── pubspec.yaml                # Flutter dependencies
└── README.md                   # This file
```

## Configuration

### Backend Configuration

**Database Path** (macOS default):
```python
DB_PATH = '~/Library/Application Support/Cursor/User/globalStorage/state.vscdb'
```

**Server Settings** in `cursor_chat_api.py`:
- Host: `0.0.0.0` (all interfaces)
- Port: `8000`
- Job retention: 1 hour for completed jobs
- Timeout: 120 seconds for cursor-agent calls

### Available AI Models

The backend supports all cursor-agent models:
- `composer-1`, `auto` (Cursor's models)
- `sonnet-4.5`, `sonnet-4.5-thinking` (Claude)
- `gpt-5`, `gpt-5-codex`, `gpt-5-codex-high` (OpenAI)
- `opus-4.1` (Claude)
- `grok`, `grok-4` (xAI)
- `gemini-2.5-pro`, `gemini-2.5-flash` (Google)

## Development

### Running Tests

**Backend Tests:**
```bash
cd rest
pytest                           # All tests
pytest test_cursor_agent.py      # Cursor agent integration
pytest test_api.py              # API endpoints
```

**Frontend:**
```bash
flutter test
```

### Development Mode

**Backend with auto-reload:**
```bash
cd rest
uvicorn cursor_chat_api:app --reload --host 0.0.0.0 --port 8000
```

**Frontend with hot reload:**
```bash
flutter run
# Press 'r' to hot reload, 'R' to hot restart
```

## Troubleshooting

### Backend Issues

**Database not found:**
- Ensure Cursor IDE is installed
- Check database path in `cursor_chat_api.py`
- Verify path: `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`

**cursor-agent not found:**
```bash
# Install cursor-agent
curl https://cursor.com/install -fsS | bash

# Verify installation
cursor-agent --version

# Check path (should be ~/.local/bin/cursor-agent)
which cursor-agent
```

**Authentication errors:**
```bash
# Login to Cursor
cursor-agent login
```

### Frontend Issues

**Cannot connect to API:**
- Verify backend is running: `curl http://localhost:8000/health`
- Check firewall settings
- For physical devices, ensure Mac and device are on same network
- Update IP address in `cursor_agent_service.dart`

**Build errors:**
```bash
flutter clean
flutter pub get
flutter run
```

## Architecture Decisions

### Why Async Jobs?

Cursor-agent calls can take 5-30 seconds. Async jobs provide:
- **Non-blocking UI** - User can navigate while waiting
- **Better UX** - Progress indicators and elapsed time
- **Concurrent processing** - Multiple jobs can run simultaneously
- **Error recovery** - Jobs can be retried or cancelled

### Why Direct Database Access?

Reading/writing Cursor's SQLite database directly:
- **Instant sync** - Changes appear in Cursor IDE immediately
- **No API dependency** - Works offline
- **Full access** - All chat metadata and content
- **Performance** - No network overhead for reads

### Why cursor-agent CLI?

- **Official tool** - Maintained by Cursor team
- **Model routing** - Handles all AI model complexity
- **Authentication** - Uses Cursor's existing auth
- **History magic** - `--resume` flag handles context automatically

## Requirements

- **Backend:**
  - Python 3.8+
  - FastAPI, uvicorn, sqlite3
  - cursor-agent CLI
  - macOS (for default database path)

- **Frontend:**
  - Flutter 3.0+
  - Dart 3.0+
  - iOS 12+ / Android 6+

- **System:**
  - Cursor IDE installed
  - Network access between frontend and backend

## License

MIT

## Contributing

Contributions welcome! Areas for improvement:
- Streaming support (SSE for real-time responses)
- Message editing and deletion
- Chat archiving/organization
- Search functionality
- Export conversations
- Multi-user support

## Support

- **Backend API Docs:** `http://localhost:8000/docs`
- **Backend README:** `rest/README.md`
- **Issues:** GitHub issues for bug reports

---

**Built with Flutter, FastAPI, and cursor-agent**
