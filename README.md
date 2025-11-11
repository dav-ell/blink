# Blink - Cursor Chat Manager

Manage Cursor CLI agents from your phone. Blink is a Flutter mobile application that allows you to monitor and interact with your Cursor IDE chat sessions from anywhere.

## Features

### Current Implementation (Stage 1)
- 📱 View all ongoing Cursor IDE chat sessions
- 💬 View complete chat history for each session
- 📤 Send messages and commands to Cursor (even when not running)
- 🔄 Session status indicators (Active, Idle, Completed)
- 🎨 Modern Material 3 design with dark mode support
- ⚡ Real-time session updates

### Data Models
- **ChatSession**: Represents a chat session with metadata (title, status, timestamps, message count)
- **ChatMessage**: Represents individual messages with sender, type, and content
- **Status tracking**: Active, Idle, and Completed session states

### Mock Data Implementation
Currently, all data is mocked for development purposes. The app includes comprehensive TODO comments indicating where backend API calls need to be integrated.

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── models/
│   ├── chat_session.dart        # Chat session data model
│   └── chat_message.dart        # Chat message data model
├── services/
│   └── chat_service.dart        # Service layer with mock data & API TODOs
└── screens/
    ├── chat_list_screen.dart    # List all chat sessions
    └── chat_detail_screen.dart  # View & interact with a session
```

## Backend Integration TODOs

The following API endpoints need to be implemented in the Cursor CLI backend:

### Sessions
- `GET /api/sessions` - Fetch all chat sessions
- `POST /api/sessions` - Create a new session
- `DELETE /api/sessions/{sessionId}` - Delete a session
- `PATCH /api/sessions/{sessionId}` - Update session status

### Messages
- `GET /api/sessions/{sessionId}/messages` - Fetch messages for a session
- `POST /api/sessions/{sessionId}/messages` - Send a message to a session

All API integration points are marked with `// TODO:` comments in `lib/services/chat_service.dart`.

## Installation

### Prerequisites
- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.0.0)
- Android Studio / Xcode (for mobile development)

### Setup
```bash
# Clone the repository
git clone https://github.com/dav-ell/blink.git
cd blink

# Install dependencies
flutter pub get

# Run the app
flutter run
```

## Usage

1. **View Sessions**: Open the app to see all your Cursor chat sessions
2. **View History**: Tap any session to view its complete message history
3. **Send Commands**: Use the text input to send messages or commands to Cursor
   - Regular messages: Just type and send
   - Commands: Start with `/` for command-type messages
4. **Create New Session**: Tap the "New Session" button to start a new chat
5. **Refresh**: Pull down to refresh or use the refresh button

## Session Status

- 🟢 **Active**: Cursor is currently running and processing
- 🟠 **Idle**: Cursor is not running but ready to receive commands
- ⚪ **Completed**: Session has ended

## Next Steps (Future Stages)

- [ ] Implement real backend API integration
- [ ] Add authentication and user management
- [ ] Real-time WebSocket updates for active sessions
- [ ] Push notifications for session updates
- [ ] Code syntax highlighting for code messages
- [ ] File attachment support
- [ ] Search and filter sessions
- [ ] Export chat history
- [ ] Settings and preferences

## Development

### Linting
```bash
flutter analyze
```

### Testing
```bash
flutter test
```

### Building
```bash
# Android
flutter build apk

# iOS
flutter build ios
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

See [LICENSE](LICENSE) file for details.
