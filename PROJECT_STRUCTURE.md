# Blink - Project Structure

## Overview
A Flutter mobile application for managing Cursor IDE chat sessions remotely.

## Project Statistics
- **Total Lines of Code:** ~1,167 lines
- **Dart Files:** 9 files (6 main + 3 test)
- **Models:** 2 (ChatSession, ChatMessage)
- **Services:** 1 (ChatService with mock data)
- **Screens:** 2 (ChatListScreen, ChatDetailScreen)

## File Structure

```
blink/
├── lib/
│   ├── main.dart                      (33 lines)  - App entry point
│   ├── models/
│   │   ├── chat_session.dart          (44 lines)  - Session data model
│   │   └── chat_message.dart          (52 lines)  - Message data model
│   ├── services/
│   │   └── chat_service.dart          (190 lines) - Service with mock data & API TODOs
│   └── screens/
│       ├── chat_list_screen.dart      (243 lines) - Sessions list view
│       └── chat_detail_screen.dart    (377 lines) - Chat history & messaging
│
├── test/
│   ├── widget_test.dart               (40 lines)  - Main app widget tests
│   ├── models_test.dart               (118 lines) - Model unit tests
│   └── chat_service_test.dart         (110 lines) - Service unit tests
│
├── android/                                        - Android configuration
│   ├── app/
│   │   ├── build.gradle
│   │   └── src/main/
│   │       ├── AndroidManifest.xml
│   │       └── kotlin/.../MainActivity.kt
│   ├── build.gradle
│   └── settings.gradle
│
├── pubspec.yaml                                    - Dependencies
├── analysis_options.yaml                           - Linting rules
└── README.md                                       - Documentation

```

## Key Components

### Data Models
1. **ChatSession** - Represents a chat session
   - Properties: id, title, startTime, lastActivityTime, status, messageCount
   - Enums: ChatStatus (active, idle, completed)

2. **ChatMessage** - Represents a message
   - Properties: id, sessionId, content, timestamp, sender, type
   - Enums: MessageSender (user, cursor, system), MessageType (text, command, code, error)

### Service Layer
**ChatService** (Singleton)
- Mock implementations with TODO comments for:
  - `getSessions()` → GET /api/sessions
  - `getMessages(sessionId)` → GET /api/sessions/{id}/messages
  - `sendMessage()` → POST /api/sessions/{id}/messages
  - `createSession()` → POST /api/sessions
  - `deleteSession()` → DELETE /api/sessions/{id}
  - `updateSessionStatus()` → PATCH /api/sessions/{id}

### User Interface

#### ChatListScreen
- Displays all chat sessions
- Features:
  - Pull-to-refresh
  - Session status badges
  - Message count indicator
  - Time-based activity display
  - Create new session FAB
  - Navigation to detail view

#### ChatDetailScreen
- Shows conversation history
- Features:
  - Message bubbles (user vs cursor)
  - Message type indicators (text, command, code)
  - Send messages/commands
  - Session info dialog
  - Status-based UI hints
  - Auto-scroll to latest message

## Testing
- **Widget Tests:** App initialization, theme configuration
- **Model Tests:** Data model creation, copyWith functionality, enum validation
- **Service Tests:** CRUD operations, singleton pattern, data validation

## Mock Data
All data is currently mocked to demonstrate functionality. Each API method includes:
1. Simulated network delay
2. Mock data response
3. TODO comment with exact API endpoint specification

## Next Steps for Backend Integration
1. Set up API client (e.g., dio, http)
2. Implement authentication
3. Replace mock methods with real API calls
4. Add error handling and retry logic
5. Implement WebSocket for real-time updates
6. Add data persistence/caching

## Design Decisions
- **Material 3:** Modern, adaptive UI design
- **Singleton Service:** Single instance for data management
- **Mock-first:** Easy to replace with real implementation
- **TODO-driven:** Clear integration points documented
- **Type-safe:** Strong typing for all data models
- **Testable:** Unit tests cover core functionality
